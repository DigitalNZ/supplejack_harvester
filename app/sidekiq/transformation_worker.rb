# frozen_string_literal: true

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

    valid_records       = select_valid_records(transformed_records)
    rejected_records    = transformed_records.select { |record| record['rejection_reasons'].present? }
    deleted_records     = transformed_records.select { |record| record['deletion_reasons'].present? }

    update_harvest_report(transformed_records.count, rejected_records.count)

    queue_load_worker(valid_records)
    queue_delete_worker(deleted_records)
  end

  def update_harvest_report(transformed_records_count, rejected_records_count)
    @harvest_report.increment_records_transformed!(transformed_records_count)
    @harvest_report.increment_records_rejected!(rejected_records_count)
    @harvest_report.update(transformation_updated_time: Time.zone.now)
  end

  def job_end
    @harvest_report.increment_transformation_workers_completed!
    @harvest_report.reload

    return unless @harvest_report.transformation_workers_completed?

    @harvest_report.transformation_completed!

    return unless @harvest_report.delete_workers_queued.zero?

    @harvest_report.delete_completed!
  end

  def transform_records
    Transformation::Execution.new(
      records,
      @transformation_definition.fields
    ).call
  end

  def queue_load_worker(records)
    return if records.empty?

    LoadWorker.perform_async_with_priority(@pipeline_job.job_priority, @harvest_job.id, records.to_json, @api_record_id)
    Api::Utils::NotifyHarvesting.new(destination, source_id, true).call if @harvest_report.load_workers_queued.zero?
    @harvest_report.increment_load_workers_queued!
  end

  def queue_delete_worker(records)
    return if records.empty?

    DeleteWorker.perform_async_with_priority(@pipeline_job.job_priority, records.to_json, destination.id, @harvest_report.id)
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

  def select_valid_records(records)
    records.select do |record|
      record['rejection_reasons'].blank? && record['deletion_reasons'].blank?
    end
  end
end
