# frozen_string_literal: true

module Api
  class PipelineJobsController < ApplicationController
    def create
      pipeline = Pipeline.find(pipeline_job_params['pipeline_id'])

      @pipeline_job = create_pipeline_job(pipeline)

      if @pipeline_job.save
        PipelineWorker.perform_async(@pipeline_job.id)
        render json: { status: 'success' }
      else
        render json: { status: 'failed' }
      end
    end

    private

    def create_pipeline_job(pipeline)
      PipelineJob.new(pipeline_id: pipeline.id, harvest_definitions_to_run: pipeline.harvest_definitions.map(&:id),
                      destination_id: pipeline_job_params['destination_id'], key: SecureRandom.hex)
    end

    def pipeline_job_params
      params.require(:pipeline_job).permit(:pipeline_id, :destination_id)
    end
  end
end
