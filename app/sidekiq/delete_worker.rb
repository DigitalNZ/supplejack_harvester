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
  rescue StandardError
    Rails.logger.info "DeleteWorker: Delete Excecution error: #{e}" if defined?(Sidekiq)
    Supplejack::JobCompletionSummaryLogger.log_delete_worker_completion(
      exception: e,
      record: record,
      destination: destination,
      harvest_report: @harvest_report
    )
  end
end
