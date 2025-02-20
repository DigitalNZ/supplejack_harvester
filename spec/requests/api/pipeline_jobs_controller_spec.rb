# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::PipelineJobs", type: :request do
  let!(:destination)        { create(:destination) }
  let!(:pipeline) { create(:pipeline) }
  let!(:harvest_definition) { create(:harvest_definition, pipeline:) }

  describe "POST /create" do
    context 'When the job is successful' do
      it "creates a pipeline job" do
        expect do
          post api_pipeline_jobs_path, params: {
            pipeline_job: {
              destination_id: destination.id,
              pipeline_id: pipeline.id
            }
          }
        end.to change(PipelineJob, :count).by(1)
      end

      it "queues a PipelineWorker" do
        expect(PipelineWorker).to receive(:perform_async)

        post api_pipeline_jobs_path, params: {
          pipeline_job: {
            destination_id: destination.id,   
            pipeline_id: pipeline.id
          }
        }
      end
  
      it "returns that the job is successful" do
        post api_pipeline_jobs_path, params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id
          }
        }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['status']).to eq('success')
      end
    end

    context 'When the job fails' do
      it "does not create a pipeline job" do
        expect do
          post api_pipeline_jobs_path, params: {
            pipeline_job: {
              destination_id: nil,
              pipeline_id: pipeline.id
            }
          }
        end.to change(PipelineJob, :count).by(0)
      end

      it "returns that the job failed" do
        post api_pipeline_jobs_path, params: {
          pipeline_job: {
            destination_id: nil,
            pipeline_id: pipeline.id  
          }
        }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['status']).to eq('failed')
      end

      it "does not queue a PipelineWorker" do
        expect(PipelineWorker).not_to receive(:perform_async)

        post api_pipeline_jobs_path, params: {
          pipeline_job: {
            destination_id: nil,   
            pipeline_id: pipeline.id
          }
        }
      end
    end
  end
end

