# frozen_string_literal: true

class LoadWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(harvest_job_id, records, api_record_id = nil)
    @harvest_job = HarvestJob.find(harvest_job_id)
    @harvest_report = @harvest_job.harvest_report

    job_start
    transformed_records = JSON.parse(records)

    transformed_records.each_slice(100) do |batch|
      @harvest_job.reload

      break if @harvest_job.cancelled? || @harvest_job.pipeline_job.cancelled?

      process_batch(batch, api_record_id)
    end
    job_end
  end

  def log_retry_attempt
    proc do |exception, try, elapsed_time, next_interval|
      logger.info(
        "#{exception.class}: '#{exception.message}':" \
        "#{try} tries in #{elapsed_time} seconds and" \
        "#{next_interval} seconds until the next try."
      )
    end
  end

  def process_batch(batch, api_record_id)
    ::Retriable.retriable(on_retry: log_retry_attempt) do
      execute_load(batch, api_record_id)
    end
  rescue StandardError => batch_error
    handle_load_error(batch_error)
  end

  def execute_load(batch, api_record_id)
    Load::Execution.new(batch, @harvest_job, api_record_id).call
    @harvest_report.increment_records_loaded!(batch.count)
    @harvest_report.update(load_updated_time: Time.zone.now)
  end

  def handle_load_error(error)
    logger.info "Load Excecution error: #{error}"

    JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                           error: error,
                                                                           definition:
                                                                             @harvest_job&.extraction_definition,
                                                                           job: @harvest_job&.extraction_job,
                                                                           origin: 'LoadWorker'
                                                                         })
    raise
  end

  def job_start
    @harvest_report.load_running!
  end

  def job_end
    pipeline_job = @harvest_job.pipeline_job
    @harvest_report.increment_load_workers_completed!
    @harvest_report.reload

    finish_load if @harvest_report.load_workers_completed?

    pipeline_job.enqueue_enrichment_jobs(@harvest_job.name)
    @harvest_job.execute_delete_previous_records

    return unless pipeline_job.reload.finished?

    pipeline_job.completed!
  end

  def source_id
    @harvest_job.pipeline_job.pipeline.harvest_definitions.first.source_id
  end

  def destination
    @harvest_job.pipeline_job.destination
  end

  private

  def finish_load
    @harvest_report.load_completed!

    ::Retriable.retriable(on_retry: log_retry_attempt) do
      Api::Utils::NotifyHarvesting.new(destination, source_id, false).call
    end
  rescue StandardError => notify_error
    logger.info "LoadWorker: API Utils NotifyHarvesting error: #{notify_error.message}"
  end
end
