# frozen_string_literal: true

module Api
  class PipelineJobsController < ApplicationController
    def create
      pipeline = Pipeline.find(pipeline_job_params['pipeline_id'])

      @pipeline_job = create_pipeline_job(pipeline)

      if @pipeline_job.save
        PipelineWorker.perform_async_with_priority(@pipeline_job.job_priority, @pipeline_job.id)
        render json: { status: 'success' }
      else
        render json: { status: 'failed' }
      end
    end

    private

    def create_pipeline_job(pipeline)
      PipelineJob.new(pipeline_id: pipeline.id,
                      harvest_definitions_to_run: harvest_definitions_to_run(pipeline),
                      destination_id: pipeline_job_params['destination_id'],
                      job_priority: pipeline_job_params['job_priority'])
    end

    def pipeline_job_params
      params.require(:pipeline_job).permit(:pipeline_id, :destination_id, :job_priority, harvest_definitions_to_run: [])
    end

    def harvest_definitions_to_run(pipeline)
      if harvest_definitions_to_run_params.present? && harvest_definitions_to_run_params.any?(&:present?)
        return harvest_definitions_to_run_params.compact_blank
      end

      pipeline.harvest_definitions.map { |definition| definition.id.to_s }
    end

    def harvest_definitions_to_run_params
      pipeline_job_params[:harvest_definitions_to_run]
    end
  end
end
