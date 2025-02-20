# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::PipelineStatuses", type: :request do
  let(:pipeline) { create(:pipeline) }
  let(:destination) { create(:destination) }
  let(:admin_user) { create(:user, api_key: 'key', role: :admin) }
  let(:user) { create(:user, api_key: 'key') }
  
  describe "GET /show" do
    context 'when the user is using an admin api key' do
      context 'when the pipeline has a queued job' do
        let!(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }

        it 'returns queued' do
          get api_pipeline_status_path(pipeline), headers: { 
            "Authorization" => "Token token=#{admin_user.api_key}"
          }

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['status']).to eq('queued')
        end
      end

      context 'when the pipeline has a running job' do
        let!(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }

        let(:harvest_definition) { create(:harvest_definition, pipeline:) }
        let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }
        let!(:running) do
          create(:harvest_report, pipeline_job:, harvest_job:, extraction_status: 'running', transformation_status: 'queued',
                                  load_status: 'queued', delete_status: 'queued')
        end

        it 'returns running' do
          get api_pipeline_status_path(pipeline), headers: { 
            "Authorization" => "Token token=#{admin_user.api_key}"
          }

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['status']).to eq('running')
        end
      end

      context 'when the pipeline has no jobs' do
        it 'returns inactive' do
          get api_pipeline_status_path(pipeline), headers: { 
            "Authorization" => "Token token=#{admin_user.api_key}"
          }

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['status']).to eq('inactive')
        end
      end
    end

    context 'when the user is not using an admin api key' do
      it 'returns a 401' do
        get api_pipeline_status_path(pipeline)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
