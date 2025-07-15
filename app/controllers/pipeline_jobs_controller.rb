# frozen_string_literal: true

class PipelineJobsController < ApplicationController
  before_action :find_pipeline
  before_action :find_pipeline_job, only: %i[show cancel]

  def index
    @pipeline_jobs = paginate_and_filter_jobs(@pipeline.pipeline_jobs)
  end

  def show; end

  # rubocop:disable Metrics/AbcSize
  def create
    @pipeline_job = PipelineJob.new(pipeline_job_params.merge(launched_by_id: current_user.id))

    if @pipeline_job.save
      PipelineWorker.perform_async_with_priority(@pipeline_job.job_priority, @pipeline_job.id)
      flash.notice = t('.success')
    else
      flash.alert = t('.failure')
    end

    redirect_to pipeline_pipeline_jobs_path(@pipeline)
  end
  # rubocop:enable Metrics/AbcSize

  def cancel
    if @pipeline_job.cancelled!
      @pipeline_job.harvest_jobs.each(&:cancel)

      flash.notice = t('.success')
    else
      flash.alert = t('.failure')
    end

    redirect_to pipeline_pipeline_jobs_path(@pipeline)
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_pipeline_job
    @pipeline_job = PipelineJob.find(params[:id])
  end

  def pipeline_job_params
    params.require(:pipeline_job).permit(:pipeline_id, :key, :extraction_job_id, :destination_id,
                                         :page_type, :pages, :delete_previous_records, :run_enrichment_concurrently,
                                         :job_priority, harvest_definitions_to_run: [])
  end
end
