# frozen_string_literal: true

class ExtractionWorker < ApplicationWorker
  sidekiq_retries_exhausted do |job, _ex|
    @job = ExtractionJob.find(job['args'].first)
    @job.errored!
    @job.update(error_message: job['error_message'])
    Rails.logger.warn "Failed #{job['class']} with #{job['args']}: #{job['error_message']}"
  end

  # rubocop:disable Metrics/AbcSize
  def child_perform(extraction_job)
    if extraction_job.extraction_definition.enrichment?
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
  # rubocop:enable Metrics/AbcSize

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
    @harvest_report.extraction_completed! unless @job.extraction_definition.extract_text_from_file?
    @harvest_report.transformation_completed! if @harvest_report.transformation_workers_completed?
    @harvest_report.load_completed! if @harvest_report.load_workers_completed?
    @harvest_report.delete_completed! if @harvest_report.delete_workers_completed?
    
    # Check if all ExtractionJobs in this step are complete, then trigger MultiItemWorker
    check_and_trigger_multi_item_worker if @harvest_report.extraction_completed?
  end

  def check_and_trigger_multi_item_worker
    return unless @harvest_report.present?
    
    harvest_job = @harvest_report.harvest_job
    return unless harvest_job.present?
    
    pipeline_job = harvest_job.pipeline_job
    return unless pipeline_job.from_automation?
    
    # Check if ALL ExtractionJobs in this HarvestJob are complete
    all_extraction_jobs = harvest_job.all_extraction_jobs
    return unless all_extraction_jobs.any?  # Must have at least one extraction job
    return unless all_extraction_jobs.all?(&:completed?)
    
    # Check if next step needs multi-item extraction
    current_step = pipeline_job.automation_step
    next_step = current_step.next_step
    return unless next_step
    
    has_multi_item = next_step.harvest_definitions.any? do |harvest_def|
      extraction_def = harvest_def.extraction_definition
      # Check both new and old field names for backward compatibility
      (extraction_def.respond_to?(:multi_item_extraction_enabled?) && extraction_def.multi_item_extraction_enabled?) ||
      (extraction_def.respond_to?(:link_extraction_enabled?) && extraction_def.link_extraction_enabled?)
    end
    
    return unless has_multi_item
    
    # Trigger MultiItemWorker for the entire step (pass the HarvestJob, not individual ExtractionJob)
    MultiItemWorker.perform_async_with_priority(
      pipeline_job.job_priority,
      harvest_job.id  # Pass HarvestJob ID instead of ExtractionJob ID
    )
  end

  def trigger_following_processes
    harvest_job = @harvest_report.harvest_job

    @harvest_report.pipeline_job.enqueue_enrichment_jobs(harvest_job.name)
    harvest_job.execute_delete_previous_records
  end
end
