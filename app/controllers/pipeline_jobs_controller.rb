# frozen_string_literal: true

class PipelineJobsController < ApplicationController
  before_action :find_pipeline
  before_action :find_pipeline_job, only: %i[show cancel]
  before_action :complete_finished_jobs

  def index
    @pipeline_jobs = paginate_and_filter_jobs(@pipeline.pipeline_jobs)
  end

  def show; end

  def create
    @pipeline_job = PipelineJob.new(pipeline_job_params.merge(launched_by_id: current_user.id))

    if @pipeline_job.save
      PipelineWorker.perform_async(@pipeline_job.id)
      flash.notice = t('.success')
    else
      flash.alert = t('.failure')
    end

    redirect_to pipeline_pipeline_jobs_path(@pipeline)
  end

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

  # we have noticed an issue where jobs are not being appropriately marked as completed during the worker lifecycle
  # this is being caused by latency between the concurrent sidekiq process and the database
  # future plan is to introduce a watching process as part of the harvest and move logic
  # about completions and scheduling enrichments there
  def complete_finished_jobs
    running_reports = @pipeline.pipeline_jobs.flat_map(&:harvest_reports).select do |report|
      report.status == 'running'
    end

    running_reports.each do |report|
      report.update(transformation_status: 'completed') if report.transformation_workers_completed?
      report.update(load_status: 'completed') if report.load_workers_completed?
      report.update(delete_status: 'completed') if report.delete_workers_completed?
    end
  end

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_pipeline_job
    @pipeline_job = PipelineJob.find(params[:id])
  end

  def pipeline_job_params
    params.require(:pipeline_job).permit(:pipeline_id, :key, :extraction_job_id, :destination_id,
                                         :page_type, :pages, :delete_previous_records, :run_enrichment_concurrently,
                                         harvest_definitions_to_run: [])
  end
end
