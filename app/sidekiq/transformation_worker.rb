# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class TransformationWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(harvest_job_id, page = 1, api_record_id = nil)
    @harvest_job = HarvestJob.find(harvest_job_id)
    @extraction_job = @harvest_job.extraction_job
    @transformation_definition = TransformationDefinition.find(@harvest_job.transformation_definition.id)
    @harvest_report = @harvest_job.harvest_report
    @page = page
    @api_record_id = api_record_id
    @pipeline_job = @harvest_job.pipeline_job

    job_start
    child_perform
    job_end
  end

  def job_start
    @harvest_report.transformation_running!
  end

  def child_perform
    transformed_records = transform_records.map(&:to_hash)

    @harvest_job.reload
    return if @harvest_job.cancelled? || @pipeline_job.cancelled?

    process_transformed_records(transformed_records)
  end

  private

  # ---------------------------
  # JSON SANITIZATION + DEBUGGING
  # ---------------------------

  def sanitize_record(record)
    case record
    when Hash
      record.each_with_object({}) do |(k, v), safe_hash|
        safe_hash[k.to_s] = sanitize_record(v)
      end
    when Array
      record.map { |v| sanitize_record(v) }
    when Symbol
      record.to_s
    when Numeric, TrueClass, FalseClass, NilClass
      record
    when String
      record.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    else
      record.to_s
    end
  end

  def sanitize_and_debug(records, context:)
    records.map do |record|
      sanitized = sanitize_record(record)

      begin
        MultiJson.dump(sanitized)
      rescue StandardError => e
        Airbrake.notify("[#{context}] Invalid JSON record detected")
        Airbrake.notify("Error: #{e.class} - #{e.message}")
        Airbrake.notify("Original record: #{record.inspect}")
        Airbrake.notify("Sanitized record: #{sanitized.inspect}")
      end

      sanitized
    end
  end

  # ---------------------------
  # RECORD PROCESSING
  # ---------------------------

  def process_transformed_records(transformed_records)
    valid_records, rejected_records, deleted_records = categorize_records(transformed_records)

    update_harvest_report(transformed_records.count, rejected_records.count)

    queue_load_worker(valid_records)
    queue_delete_worker(deleted_records)
  end

  def categorize_records(transformed_records)
    valid_records = []
    rejected_records = []
    deleted_records = []

    transformed_records.each do |record|
      categorize_single_record(record, valid_records, rejected_records, deleted_records)
    end

    [valid_records, rejected_records, deleted_records]
  end

  def categorize_single_record(record, valid_records, rejected_records, deleted_records)
    rejection_reasons = record["rejection_reasons"]
    deletion_reasons = record["deletion_reasons"]

    if rejection_reasons.blank? && deletion_reasons.blank?
      valid_records << record
    elsif rejection_reasons.present?
      rejected_records << record
    elsif deletion_reasons.present?
      deleted_records << record
    end
  end

  def update_harvest_report(transformed_records_count, rejected_records_count)
    @harvest_report.increment_records_transformed!(transformed_records_count)
    @harvest_report.increment_records_rejected!(rejected_records_count)
    @harvest_report.update(transformation_updated_time: Time.zone.now)
  end

  # ---------------------------
  # SIDEKIQ QUEUING (SAFE)
  # ---------------------------

  def queue_load_worker(records)
    return if records.empty?

    @harvest_job.reload
    return if @harvest_job.cancelled? || @pipeline_job.cancelled?

    safe_records = sanitize_and_debug(records, context: "LoadWorker")

    LoadWorker.perform_async_with_priority(
      @pipeline_job.job_priority,
      @harvest_job.id,
      safe_records,
      @api_record_id
    )

    notify_harvesting_api
    @harvest_report.increment_load_workers_queued!
  end

  def queue_delete_worker(records)
    return if records.empty?

    safe_records = sanitize_and_debug(records, context: "DeleteWorker")

    DeleteWorker.perform_async_with_priority(
      @pipeline_job.job_priority,
      safe_records,
      destination.id,
      @harvest_report.id
    )

    @harvest_report.increment_delete_workers_queued!
  end

  # ---------------------------
  # JOB LIFECYCLE
  # ---------------------------

  def job_end
    @harvest_report.increment_transformation_workers_completed!
    @harvest_report.reload

    return unless @harvest_report.transformation_workers_completed?

    handle_transformation_completion
  end

  def handle_transformation_completion
    @harvest_report.transformation_completed!
    @harvest_report.load_completed! if @harvest_report.load_workers_completed?
    @harvest_report.delete_completed! if @harvest_report.delete_workers_completed?

    return unless @harvest_report.delete_workers_queued.zero?

    @harvest_report.delete_completed!
    @harvest_report.transformation_completed!
  end

  # ---------------------------
  # TRANSFORMATION
  # ---------------------------

  def transform_records
    Transformation::Execution
      .new(records, @transformation_definition.fields)
      .call
  rescue StandardError => e
    handle_transform_error(e)
    []
  end

  def handle_transform_error(error)
    JobCompletionServices::ContextBuilder.create_job_completion_or_error(
      error: error,
      definition: @transformation_definition,
      job: @harvest_job,
      origin: "TransformationWorker"
    )
  end

  # ---------------------------
  # MISC
  # ---------------------------

  def notify_harvesting_api
    ::Retriable.retriable(on_retry: log_retry_attempt) do
      Api::Utils::NotifyHarvesting
        .new(destination, source_id, true)
        .call if @harvest_report.load_workers_queued.zero?
    end
  rescue StandardError => e
    JobCompletionServices::ContextBuilder.create_job_completion_or_error(
      error: e,
      definition: @transformation_definition,
      job: @harvest_job,
      origin: "TransformationWorker"
    )
  end

  def source_id
    @pipeline_job.pipeline.harvest_definitions.first.source_id
  end

  def destination
    @pipeline_job.destination
  end

  def records
    Transformation::RawRecordsExtractor
      .new(@transformation_definition, @extraction_job)
      .records(@page)
  end

  def log_retry_attempt
    proc do |exception, try, elapsed_time, next_interval|
      logger.info(
        "#{exception.class}: '#{exception.message}': #{try} tries in #{elapsed_time}s, next retry in #{next_interval}s"
      )
    end
  end
end
# rubocop:enable Metrics/ClassLength
