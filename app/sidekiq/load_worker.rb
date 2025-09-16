# frozen_string_literal: true

class LoadWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  # rubocop:disable Metrics/MethodLength
  def perform(harvest_job_id, records_json, api_record_id = nil)
    setup(harvest_job_id)

    job_start

    transformed_records = JSON.parse(records_json)

    transformed_records.each_slice(100) do |batch|
      break if cancelled?

      process_batch(batch, api_record_id)
    end

    job_end
  rescue StandardError => e
    Rails.logger.error "LoadWorker: Job failure - #{e.class}: #{e.message}"
    raise
  end
  # rubocop:enable Metrics/MethodLength

  private

  def setup(harvest_job_id)
    @harvest_job = HarvestJob.find(harvest_job_id)
    @harvest_report = @harvest_job.harvest_report
    @pipeline_job = @harvest_job.pipeline_job
    @source_id = @pipeline_job.pipeline.harvest_definitions.first.source_id
    @destination = @pipeline_job.destination
  end

  def cancelled?
    @harvest_job.reload
    @harvest_job.cancelled? || @pipeline_job.cancelled?
  end

  def job_start
    @harvest_report.load_running!
  end

  def job_end
    @harvest_report.increment_load_workers_completed!
    @harvest_report.reload

    finish_load if @harvest_report.load_workers_completed?

    @pipeline_job.enqueue_enrichment_jobs(@harvest_job.name)
    @harvest_job.execute_delete_previous_records
  end

  def process_batch(batch, api_record_id)
    ::Retriable.retriable(on_retry: log_retry_attempt) do
      Load::Execution.new(batch, @harvest_job, api_record_id).call

      @harvest_report.increment_records_loaded!(batch.size)
      @harvest_report.update(load_updated_time: Time.zone.now)
    end
  rescue StandardError => e
    Rails.logger.error "LoadWorker: Error in batch processing - #{e.class}: #{e.message}"
  end

  def finish_load
    @harvest_report.load_completed!

    ::Retriable.retriable(on_retry: log_retry_attempt) do
      Api::Utils::NotifyHarvesting.new(@destination, @source_id, false).call
    end
  rescue StandardError => e
    Rails.logger.info "LoadWorker: API Utils NotifyHarvesting error: #{e.message}" if defined?(Sidekiq)
  end

  def log_retry_attempt
    proc do |exception, try, elapsed_time, next_interval|
      Rails.logger.warn(
        "Retrying after #{exception.class}: #{exception.message} - " \
        "Attempt ##{try}, elapsed #{elapsed_time}s, next try in #{next_interval}s."
      )
    end
  end
end
