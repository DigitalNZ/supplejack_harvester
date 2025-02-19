# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::PipelineJobs", type: :request do
  let!(:destination)        { create(:destination) }
  let!(:pipeline) { create(:pipeline) }
  let!(:harvest_definition) { create(:harvest_definition, pipeline:) }

  describe "POST /create" do
    it "create a pipeline job" do

      post api_pipeline_jobs_path, params: {
        pipeline_job: {
          destination_id: destination.id,
          pipeline_id: pipeline.id
        }
      }

      # expect do
      #   post api_pipeline_jobs_path, params: {
      #     pipeline_job: {
      #       destination_id: destination.id,
      #       pipeline_id: pipeline.id
      #     }
      #   }
      # end.to change(PipelineJob, :count).by(1)
    end
  end
end

