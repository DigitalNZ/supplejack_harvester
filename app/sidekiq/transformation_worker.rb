# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class TransformationWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(harvest_job_id, page = 1, api_record_id = nil, extraction_job_id = nil)
    @harvest_job = HarvestJob.find(harvest_job_id)
    @extraction_job = find_extraction_job(extraction_job_id)
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
    rejection_reasons = record['rejection_reasons']
    deletion_reasons = record['deletion_reasons']

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

  def job_end
    @harvest_report.increment_transformation_workers_completed!
    @harvest_report.reload

    transformation_workers_completed = @harvest_report.transformation_workers_completed?
    return unless transformation_workers_completed

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

  def transform_records
    Transformation::Execution.new(records, @transformation_definition.fields).call
  rescue StandardError => e
    handle_transform_error(e)
    []
  end

  def handle_transform_error(error)
    JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                           error: error,
                                                                           definition: @transformation_definition,
                                                                           job: @harvest_job,
                                                                           origin: 'TransformationWorker'
                                                                         })
  end

  def queue_load_worker(records)
    return if records.empty?

    @harvest_job.reload

    return if @harvest_job.cancelled? || @pipeline_job.cancelled?

    LoadWorker.perform_async_with_priority(@pipeline_job.job_priority, @harvest_job.id, records.to_json, @api_record_id)

    notify_harvesting_api
    @harvest_report.increment_load_workers_queued!
  end

  def notify_harvesting_api
    ::Retriable.retriable(on_retry: log_retry_attempt) do
      Api::Utils::NotifyHarvesting.new(destination, source_id, true).call if @harvest_report.load_workers_queued.zero?
    end
  rescue StandardError => e
    JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                           error: e,
                                                                           definition: @transformation_definition,
                                                                           job: @harvest_job,
                                                                           origin: 'TransformationWorker'
                                                                         })
  end

  def queue_delete_worker(records)
    return if records.empty?

    DeleteWorker.perform_async_with_priority(@pipeline_job.job_priority, records.to_json, destination.id,
                                             @harvest_report.id)
    @harvest_report.increment_delete_workers_queued!
  end

  def source_id
    @pipeline_job.pipeline.harvest_definitions.first.source_id
  end

  def destination
    @pipeline_job.destination
  end

  def records
    Transformation::RawRecordsExtractor.new(@transformation_definition, @extraction_job).records(@page)
  end

  def find_extraction_job(extraction_job_id)
    # If extraction_job_id is provided, use that specific extraction job
    return ExtractionJob.find(extraction_job_id) if extraction_job_id.present?
    
    # Otherwise, get the first available extraction job (backward compatibility)
    all_extraction_jobs = @harvest_job.all_extraction_jobs
    return all_extraction_jobs.first if all_extraction_jobs.any?
    
    # Fallback to old relationship
    @harvest_job.extraction_job
  end

  def log_retry_attempt
    proc do |exception, try, elapsed_time, next_interval|
      return unless defined?(Sidekiq)

      Rails.logger.info("#{exception.class}: '#{exception.message}': #{try} tries in #{elapsed_time} seconds " \
                        "and #{next_interval} seconds until the next try.")
    end
  end
end
# rubocop:enable Metrics/ClassLength
