# frozen_string_literal: true

class LoadWorker
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(harvest_job_id, records, api_record_id = nil)
    @harvest_job = HarvestJob.find(harvest_job_id)
    @harvest_report = @harvest_job.harvest_report

    job_start

    transformed_records = JSON.parse(records)

    transformed_records.each_slice(100) do |batch|
      process_batch(batch, api_record_id)
    end

    job_end
  end

  # :reek:UncommunicativeVariableName
  # this reek has been ignored as 'e' is the variable name wanted by Rubocop
  def process_batch(batch, api_record_id)
    ::Retriable.retriable(tries: 5, base_interval: 1, multiplier: 2) do
      Load::Execution.new(batch, @harvest_job, api_record_id).call

      @harvest_report.increment_records_loaded!(batch.count)
      @harvest_report.update(load_updated_time: Time.zone.now)
    end
  rescue StandardError => e
    ::Sidekiq.logger.info "Load Excecution error: #{e}" if defined?(Sidekiq)
  end

  def job_start
    @harvest_report.load_running!
  end

  def job_end
    @harvest_report.increment_load_workers_completed!
    @harvest_report.reload

    @harvest_report.load_completed! if @harvest_report.load_workers_completed?

    @harvest_job.pipeline_job.enqueue_enrichment_jobs(@harvest_job.name)
    @harvest_job.execute_delete_previous_records
  end
end
