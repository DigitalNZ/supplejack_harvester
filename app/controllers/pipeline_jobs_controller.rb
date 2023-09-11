# frozen_string_literal: true

class PipelineJobsController < ApplicationController
  before_action :find_pipeline

  def index
    @pipeline_jobs = paginate_and_filter_jobs(@pipeline.pipeline_jobs)    
  end

  def show
    @pipeline_job = PipelineJob.find(params[:id])
  end

  def create
    @pipeline_job = PipelineJob.new(pipeline_job_params)

    @pipeline_job.save!

    PipelineWorker.perform_async(@pipeline_job.id)

    redirect_to pipeline_pipeline_jobs_path(@pipeline)
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def pipeline_job_params
    params.require(:pipeline_job).permit(:pipeline_id, :key, :extraction_job_id, :destination_id, :page_type, :pages, harvest_definitions_to_run: [])
  end
end