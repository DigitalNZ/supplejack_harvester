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

  def process_transformed_records(transformed_records)
    valid_records, rejected_records, deleted_records = categorize_records(transformed_records)

    update_harvest_report(transformed_records.count, rejected_records.count)

    if @harvest_job.load_kind == 'file'
      feed_forward(valid_records)
    else
      queue_load_worker(valid_records)
      queue_delete_worker(deleted_records)
    end
  end

  def feed_forward(records)
    return if records.empty?

    PreProcess::Output.new(@pipeline_job.id, @harvest_job.harvest_definition.position).write_page(@page, records)
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

    if @harvest_report.delete_workers_queued.zero?
      @harvest_report.delete_completed!
      @harvest_report.transformation_completed!
    end

    # A preprocess block completes when its transformation completes (it queues no
    # loads/deletes), so the chain can step forward from here. HarvestJob#advance_chain
    # decides, because the extraction worker reaches the same point by another route.
    @harvest_job.advance_chain

    # And a harvest block that queued no loads is complete here too, so this is the only
    # worker left to queue its enrichments. HarvestJob#queue_enrichments decides.
    @harvest_job.queue_enrichments
  end

  def transform_records
    Transformation::Execution.new(records, @transformation_definition.fields, harvest_job: @harvest_job).call
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
      Api::Utils::NotifyHarvesting.new(destination, source_id, true).call if notify_harvesting?
    end
  rescue StandardError => e
    JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                           error: e,
                                                                           definition: @transformation_definition,
                                                                           job: @harvest_job,
                                                                           origin: 'TransformationWorker'
                                                                         })
  end

  def notify_harvesting?
    source_id.present? && @harvest_report.load_workers_queued.zero?
  end

  # A block writing a secondary fragment does not own the records it touches, so a delete_if
  # on it must not mark the whole record deleted - the most it can honestly mean is that
  # this block's fragment no longer applies, and there is no way to remove just a fragment.
  # Blocks that do own their records (a harvest, an enrichment) delete as they always have.
  def queue_delete_worker(records)
    return if records.empty?
    return if @harvest_job.load_kind == 'secondary_fragment'

    DeleteWorker.perform_async_with_priority(@pipeline_job.job_priority, records.to_json, destination.id,
                                             @harvest_report.id)
    @harvest_report.increment_delete_workers_queued!
  end

  # The source whose records this run is touching, which is what the API flags as
  # harvesting so it does not de-index them mid-run. That is the pipeline's harvest
  # block, not `harvest_definitions.first` - blocks are ordered by id, so a pipeline
  # whose preprocess block was created before its harvest flagged the wrong source.
  def source_id
    @pipeline_job.pipeline.harvest&.source_id
  end

  def destination
    @pipeline_job.destination
  end

  def records
    Transformation::RawRecordsExtractor.new(@transformation_definition, @extraction_job).records(@page)
  end

  def log_retry_attempt
    proc do |exception, try, elapsed_time, next_interval|
      logger.info("#{exception.class}: '#{exception.message}': #{try} tries in #{elapsed_time} seconds " \
                  "and #{next_interval} seconds until the next try.")
    end
  end
end
# rubocop:enable Metrics/ClassLength
