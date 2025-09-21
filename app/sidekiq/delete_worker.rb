# frozen_string_literal: true

class DeleteWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(records, destination_id, harvest_report_id)
    destination = Destination.find(destination_id)
    @harvest_report = HarvestReport.find(harvest_report_id)

    records_to_delete = JSON.parse(records)

    job_start

    records_to_delete.each do |record|
      delete(record, destination)
    end

    job_end
  end

  def job_start
    @harvest_report.delete_running!
  end

  def job_end
    @harvest_report.increment_delete_workers_completed!
    @harvest_report.reload

    return unless @harvest_report.delete_workers_completed?

    @harvest_report.delete_completed!
  end

  private

  def delete(record, destination)
    Delete::Execution.new(record, destination).call
    @harvest_report.increment_records_deleted!
    @harvest_report.update(delete_updated_time: Time.zone.now)
  rescue StandardError => e
    Rails.logger.info "DeleteWorker: Delete Excecution error: #{e}" if defined?(Sidekiq)
    log_delete_worker_error(e, record, destination)
  end

  def log_delete_worker_error(exception, record, destination)
    source_id = record.dig('transformed_record', 'source_id') ||
                @harvest_report&.pipeline_job&.harvest_definitions&.first&.source_id ||
                'unknown'
    extraction_name = record.dig('transformed_record', 'job_id') ||
                      @harvest_report&.pipeline_job&.harvest_definitions&.first&.name ||
                      'unknown'

    JobCompletionSummary.log_error(
      extraction_id: source_id,
      extraction_name: extraction_name,
      message: "DeleteWorker error: #{exception.class} - #{exception.message}",
      details: {
        worker_class: self.class.name,
        exception_class: exception.class.name,
        exception_message: exception.message,
        stack_trace: exception.backtrace&.first(20),
        record: record,
        destination_id: destination.id,
        destination_name: destination.name,
        harvest_report_id: @harvest_report&.id,
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log delete worker error to JobCompletionSummary: #{e.message}"
  end
end

