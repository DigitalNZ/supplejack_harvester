# frozen_string_literal: true

class ExtractionWorker < ApplicationWorker
  sidekiq_retries_exhausted do |job, _ex|
    @job = ExtractionJob.find(job['args'].first)
    @job.errored!
    @job.update(error_message: job['error_message'])
    Sidekiq.logger.warn "Failed #{job['class']} with #{job['args']}: #{job['error_message']}"
  end

  def child_perform(extraction_job)
    if extraction_job.extraction_definition.enrichment?
      Extraction::EnrichmentExecution.new(extraction_job).call
    else
      Extraction::Execution.new(extraction_job, extraction_job.extraction_definition).call

      SplitWorker.perform_async(extraction_job.id) if extraction_job.extraction_definition.split
    end
  end

  def job_start
    super

    return if @harvest_report.blank?

    @harvest_report.extraction_running!
  end

  def job_end
    super

    update_harvest_report
  end

  def update_harvest_report
    return if @harvest_report.blank?

    @harvest_report.reload
    @harvest_report.extraction_cancelled!

    return if @job.cancelled?

    @harvest_report.extraction_completed!
    @harvest_report.transformation_completed! if @harvest_report.transformation_workers_completed?
    @harvest_report.load_completed! if @harvest_report.load_workers_completed?
    @harvest_report.delete_completed! if @harvest_report.delete_workers_completed?

    trigger_following_processes
  end

  def trigger_following_processes
    harvest_job = @harvest_report.harvest_job

    @harvest_report.pipeline_job.enqueue_enrichment_jobs(harvest_job.name)
    harvest_job.execute_delete_previous_records
  end
end
