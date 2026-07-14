# frozen_string_literal: true

class ExtractionWorker < ApplicationWorker
  sidekiq_retries_exhausted do |job, _ex|
    @job = ExtractionJob.find(job['args'].first)
    @job.errored!
    @job.update(error_message: job['error_message'])
    Rails.logger.warn "Failed #{job['class']} with #{job['args']}: #{job['error_message']}"
  end

  def child_perform(extraction_job)
    if iterate_previous?(extraction_job)
      Extraction::EnrichmentExecution.new(extraction_job).call
    else
      Extraction::Execution.new(extraction_job, extraction_job.extraction_definition).call

      if extraction_job.extraction_definition.split
        SplitWorker.perform_async_with_priority(job_priority, extraction_job.id)
      end
    end

    return unless extraction_job.extraction_definition.extract_text_from_file?

    TextExtractionWorker.perform_async_with_priority(job_priority, extraction_job.id)
  end

  def iterate_previous?(extraction_job)
    return true if extraction_job.extraction_definition.enrichment?

    definition = extraction_job.harvest_job&.harvest_definition
    definition.present? && definition.position.positive?
  end

  def job_priority
    return if @harvest_report.blank?

    @harvest_report.pipeline_job.job_priority
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

    if @job.cancelled?
      @harvest_report.extraction_cancelled!
      return
    end

    update_harvest_report!

    trigger_following_processes
  end

  def update_harvest_report!
    @harvest_report.extraction_completed! unless file_extraction_pending?
    @harvest_report.transformation_completed! if @harvest_report.transformation_workers_completed?
    @harvest_report.load_completed! if @harvest_report.load_workers_completed?
    @harvest_report.delete_completed! if @harvest_report.delete_workers_completed?
  end

  # SplitWorker and TextExtractionWorker run after this worker and mark the
  # extraction as completed themselves once they have processed the documents.
  def file_extraction_pending?
    @job.extraction_definition.extract_text_from_file? || @job.extraction_definition.split?
  end

  def trigger_following_processes
    harvest_job = @harvest_report.harvest_job

    @harvest_report.pipeline_job.enqueue_enrichment_jobs(harvest_job.name)
    harvest_job.execute_delete_previous_records
  end
end
