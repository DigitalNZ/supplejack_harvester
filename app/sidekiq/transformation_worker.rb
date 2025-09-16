# frozen_string_literal: true

class TransformationWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(harvest_job_id, page = 1, api_record_id = nil)
    initialize_context(harvest_job_id, page, api_record_id)

    return if cancelled?

    mark_transformation_started

    transformed_records = transform_records

    return if cancelled?

    process_transformed_records(transformed_records)

    mark_transformation_finished
  end

  private

  def initialize_context(harvest_job_id, page, api_record_id)
    @harvest_job = HarvestJob.find(harvest_job_id)
    @pipeline_job = @harvest_job.pipeline_job
    @transformation_definition = @harvest_job.transformation_definition
    @harvest_report = @harvest_job.harvest_report
    @extraction_job = @harvest_job.extraction_job
    @page = page
    @api_record_id = api_record_id
  end

  def cancelled?
    @harvest_job.cancelled? || @pipeline_job.cancelled?
  end

  def mark_transformation_started
    @harvest_report.transformation_running!
  end

  def transform_records
    raw_records = Transformation::RawRecordsExtractor.new(@transformation_definition, @extraction_job).records(@page)

    Transformation::Execution.new(raw_records, @transformation_definition.fields).call.map(&:to_hash)
  rescue StandardError => e
    Rails.logger.info "TransformationWorker: Transformation Excecution error: #{e}" if defined?(Sidekiq)
    []
  end

  def process_transformed_records(records)
    valid, rejected, deleted = categorize_records(records)

    @harvest_report.increment_records_transformed!(records.size)
    @harvest_report.increment_records_rejected!(rejected.size)
    @harvest_report.update(transformation_updated_time: Time.zone.now)

    queue_load_worker(valid)
    queue_delete_worker(deleted)
  end

  def categorize_records(records)
    valid = []
    rejected = []
    deleted = []

    records.each do |record|
      if record['rejection_reasons'].present?
        rejected << record
      elsif record['deletion_reasons'].present?
        deleted << record
      else
        valid << record
      end
    end

    [valid, rejected, deleted]
  end

  def queue_load_worker(records)
    return if records.empty?

    @harvest_job.reload
    return if cancelled?

    LoadWorker.perform_async_with_priority(@pipeline_job.job_priority, @harvest_job.id, records.to_json, @api_record_id)

    notify_harvesting_api if @harvest_report.load_workers_queued.zero?
    @harvest_report.increment_load_workers_queued!
  end

  def notify_harvesting_api
    ::Retriable.retriable(on_retry: log_retry_attempt) do
      Api::Utils::NotifyHarvesting.new(destination, source_id, true).call
    end
  rescue StandardError => e
    Rails.logger.info "TransformationWorker: API Utils NotifyHarvesting error: #{e}" if defined?(Sidekiq)
  end

  def queue_delete_worker(records)
    return if records.empty?

    DeleteWorker.perform_async_with_priority(
      @pipeline_job.job_priority,
      records.to_json,
      destination.id,
      @harvest_report.id
    )

    @harvest_report.increment_delete_workers_queued!
  end

  def mark_transformation_finished
    @harvest_report.increment_transformation_workers_completed!
    @harvest_report.reload

    return unless @harvest_report.transformation_workers_completed?

    @harvest_report.transformation_completed!

    @harvest_report.load_completed!   if @harvest_report.load_workers_completed?
    @harvest_report.delete_completed! if @harvest_report.delete_workers_completed?

    return unless @harvest_report.delete_workers_queued.zero?

    @harvest_report.delete_completed!
    @harvest_report.transformation_completed! if @harvest_report.transformation_workers_completed?
  end

  def source_id
    @pipeline_job.pipeline.harvest_definitions.first.source_id
  end

  def destination
    @pipeline_job.destination
  end

  def log_retry_attempt
    proc do |exception, try, elapsed_time, next_interval|
      Rails.logger.info("#{exception.class}: #{exception.message} (attempt #{try}, elapsed #{elapsed_time}s, retry in #{next_interval}s)")
    end
  end
end
