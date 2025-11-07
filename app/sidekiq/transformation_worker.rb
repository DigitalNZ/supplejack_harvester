# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class TransformationWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(harvest_job_id, page = 1, api_record_id = nil)
    Rails.logger.info "[TransformationWorker] Starting - harvest_job_id: #{harvest_job_id}, page: #{page}, api_record_id: #{api_record_id}"
    
    @harvest_job = HarvestJob.find(harvest_job_id)
    @extraction_job = @harvest_job.extraction_job
    @transformation_definition = TransformationDefinition.find(@harvest_job.transformation_definition.id)
    @harvest_report = @harvest_job.harvest_report
    @page = page
    @api_record_id = api_record_id
    @pipeline_job = @harvest_job.pipeline_job

    Rails.logger.info "[TransformationWorker] Initialized - pipeline_job_id: #{@pipeline_job.id}, extraction_job_id: #{@extraction_job&.id}, harvest_report_id: #{@harvest_report&.id}"

    job_start

    child_perform
    job_end
    
    Rails.logger.info "[TransformationWorker] Completed successfully - harvest_job_id: #{harvest_job_id}, page: #{page}"
  rescue StandardError => e
    Rails.logger.error "[TransformationWorker] FAILED - harvest_job_id: #{harvest_job_id}, page: #{page}, error: #{e.class} - #{e.message}"
    Rails.logger.error "[TransformationWorker] Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise
  end

  def job_start
    Rails.logger.info "[TransformationWorker] Setting transformation_running - harvest_report_id: #{@harvest_report.id}"
    @harvest_report.transformation_running!
  end

  def child_perform
    Rails.logger.info "[TransformationWorker] Starting transformation - page: #{@page}"
    transformed_records = transform_records.map(&:to_hash)
    Rails.logger.info "[TransformationWorker] Transformed #{transformed_records.count} records - page: #{@page}"

    @harvest_job.reload

    if @harvest_job.cancelled? || @pipeline_job.cancelled?
      Rails.logger.warn "[TransformationWorker] Job cancelled - harvest_job_id: #{@harvest_job.id}, cancelled: #{@harvest_job.cancelled?}, pipeline_job_cancelled: #{@pipeline_job.cancelled?}"
      return
    end

    process_transformed_records(transformed_records)
  end

  private

  def process_transformed_records(transformed_records)
    valid_records, rejected_records, deleted_records = categorize_records(transformed_records)
    
    Rails.logger.info "[TransformationWorker] Categorized records - valid: #{valid_records.count}, rejected: #{rejected_records.count}, deleted: #{deleted_records.count}"

    update_harvest_report(transformed_records.count, rejected_records.count)

    queue_load_worker(valid_records)
    queue_delete_worker(deleted_records)
  end

  def categorize_records(transformed_records)
    valid_records = transformed_records.select do |record|
      record['rejection_reasons'].blank? && record['deletion_reasons'].blank?
    end
    rejected_records = transformed_records.select { |record| record['rejection_reasons'].present? }
    deleted_records = transformed_records.select { |record| record['deletion_reasons'].present? }
    [valid_records, rejected_records, deleted_records]
  end

  def update_harvest_report(transformed_records_count, rejected_records_count)
    @harvest_report.increment_records_transformed!(transformed_records_count)
    @harvest_report.increment_records_rejected!(rejected_records_count)
    @harvest_report.update(transformation_updated_time: Time.zone.now)
  end

  def job_end
    Rails.logger.info "[TransformationWorker] Ending - incrementing transformation_workers_completed"
    @harvest_report.increment_transformation_workers_completed!
    @harvest_report.reload

    Rails.logger.info "[TransformationWorker] Worker counts - queued: #{@harvest_report.transformation_workers_queued}, completed: #{@harvest_report.transformation_workers_completed}"

    return unless @harvest_report.transformation_workers_completed?

    Rails.logger.info "[TransformationWorker] All workers completed - marking transformation_completed"
    @harvest_report.transformation_completed!
    @harvest_report.load_completed! if @harvest_report.load_workers_completed?
    @harvest_report.delete_completed! if @harvest_report.delete_workers_completed?

    return unless @harvest_report.delete_workers_queued.zero?

    @harvest_report.delete_completed!
    @harvest_report.transformation_completed! if @harvest_report.transformation_workers_completed?
  end

  def transform_records
    Rails.logger.info "[TransformationWorker] Transforming records - page: #{@page}, transformation_definition_id: #{@transformation_definition.id}"
    Transformation::Execution.new(
      records,
      @transformation_definition.fields
    ).call
  rescue StandardError => e
    Rails.logger.error "[TransformationWorker] Transformation Execution error: #{e.class} - #{e.message}"
    Rails.logger.error "[TransformationWorker] Transformation Execution backtrace: #{e.backtrace.first(5).join("\n")}"
    Rails.logger.info "TransformationWorker: Transformation Excecution error: #{e}" if defined?(Sidekiq)
    JobCompletionServices::ContextBuilder.create_job_completion({error: e, definition: @transformation_definition, job: @harvest_job,
                                           details: {}, origin: 'TransformationWorker'})
    []
  end

  def queue_load_worker(records)
    if records.empty?
      Rails.logger.info "[TransformationWorker] Skipping load_worker - no valid records"
      return
    end

    @harvest_job.reload

    if @harvest_job.cancelled? || @pipeline_job.cancelled?
      Rails.logger.warn "[TransformationWorker] Skipping load_worker - job cancelled"
      return
    end

    Rails.logger.info "[TransformationWorker] Queueing LoadWorker - records: #{records.count}, api_record_id: #{@api_record_id}"
    LoadWorker.perform_async_with_priority(@pipeline_job.job_priority, @harvest_job.id, records.to_json, @api_record_id)

    notify_harvesting_api
    @harvest_report.increment_load_workers_queued!
  end

  def notify_harvesting_api
    ::Retriable.retriable(on_retry: log_retry_attempt) do
      Api::Utils::NotifyHarvesting.new(destination, source_id, true).call if @harvest_report.load_workers_queued.zero?
    end
  rescue StandardError => e
    Rails.logger.error "[TransformationWorker] API Utils NotifyHarvesting error: #{e.class} - #{e.message}"
    Rails.logger.info "TransformationWorker: API Utils NotifyHarvesting error: #{e}" if defined?(Sidekiq)
    JobCompletionServices::ContextBuilder.create_job_completion({error: e, definition: @transformation_definition, job: @harvest_job,
                                           details: {}, origin: 'TransformationWorker'})
  end

  def queue_delete_worker(records)
    if records.empty?
      Rails.logger.info "[TransformationWorker] Skipping delete_worker - no deleted records"
      return
    end

    Rails.logger.info "[TransformationWorker] Queueing DeleteWorker - records: #{records.count}"
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
    Rails.logger.info "[TransformationWorker] Extracting raw records - page: #{@page}"
    Transformation::RawRecordsExtractor.new(@transformation_definition, @extraction_job).records(@page)
  end

  def log_retry_attempt
    proc do |exception, try, elapsed_time, next_interval|
      return unless defined?(Sidekiq)

      Rails.logger.info("[TransformationWorker] Retry attempt #{try}: #{exception.class}: '#{exception.message}' in #{elapsed_time} seconds, next in #{next_interval} seconds")
    end
  end
end
# rubocop:enable Metrics/ClassLength
