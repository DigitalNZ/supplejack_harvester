# frozen_string_literal: true

class ExtractionWorker < ApplicationWorker
  sidekiq_retries_exhausted do |job, _ex|
    @job = ExtractionJob.find(job['args'].first)
    @job.errored!
    @job.update(error_message: job['error_message'])
    Rails.logger.warn "Failed #{job['class']} with #{job['args']}: #{job['error_message']}"
  end

  def child_perform(extraction_job)
    extraction_definition = extraction_job.extraction_definition

    if iterate_previous?
      Extraction::EnrichmentExecution.new(extraction_job).call
    else
      Extraction::Execution.new(extraction_job, extraction_definition).call

      SplitWorker.perform_async_with_priority(job_priority, extraction_job.id) if extraction_definition.split
    end

    return unless extraction_definition.extract_text_from_file?

    TextExtractionWorker.perform_async_with_priority(job_priority, extraction_job.id)
  end

  # Whether this job works from records it is handed rather than seeding its own
  # extraction: an enrichment iterates the destination API, a block in the middle of a
  # chain iterates the previous block's output - either its own run's, or an earlier
  # run's when it was started on its own from the block's dropdown.
  def iterate_previous?
    return true if @job.extraction_definition.enrichment?
    return true if @job.iterates_preprocess_output?

    definition = @job.harvest_job&.harvest_definition
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

    @harvest_report.harvest_job.trigger_following_processes
  end

  def update_harvest_report!
    @harvest_report.extraction_completed! unless file_extraction_pending?

    # Transformation workers run while the extraction is still going, and each of them
    # declines to finish the report while it is (transformation_workers_completed? is
    # false until the extraction completes), leaving that to this worker. Their counters
    # therefore have to be re-read now that the extraction is marked completed: one that
    # finished between the reload in #update_harvest_report and the line above would
    # otherwise be invisible here, and neither side would finish the report - leaving a
    # block's transformation stuck on running with every worker accounted for.
    @harvest_report.reload

    @harvest_report.transformation_completed! if @harvest_report.transformation_workers_completed?
    @harvest_report.load_completed! if @harvest_report.load_workers_completed?
    @harvest_report.delete_completed! if @harvest_report.delete_workers_completed?
  end

  # SplitWorker and TextExtractionWorker run after this worker and mark the
  # extraction as completed themselves once they have processed the documents.
  def file_extraction_pending?
    @job.extraction_definition.extract_text_from_file? || @job.extraction_definition.split?
  end
end
