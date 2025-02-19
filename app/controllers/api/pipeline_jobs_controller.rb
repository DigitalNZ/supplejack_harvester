# frozen_string_literal: true

module Api
  class PipelineJobsController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :setup_two_factor_authentication

    def create
      pipeline = Pipeline.find(pipeline_job_params['pipeline_id'])
      destination = Destination.find(pipeline_job_params['destination_id'])


      @pipeline_job = PipelineJob.new(
        pipeline_id: pipeline.id, 
        harvest_definitions_to_run: pipeline.harvest_definitions.map(&:id), 
        destination:
      )

      if @pipeline_job.save
        PipelineWorker.perform_async(@pipeline_job.id)
      end
    end

    private

    def pipeline_job_params
      params.require(:pipeline_job).permit(:pipeline_id, :destination_id)
    end
  end
end
