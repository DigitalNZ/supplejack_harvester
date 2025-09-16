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

    delete(records_to_delete, destination)

    job_end
  end

  private

  def job_start
    @harvest_report.delete_running!
  end

  def job_end
    @harvest_report.increment_delete_workers_completed!
    @harvest_report.reload

    @harvest_report.delete_completed! if @harvest_report.delete_workers_completed?

    # Move this here to update just once per job
    @harvest_report.update(delete_updated_time: Time.zone.now)
  end

  def delete(records, destination)
    records.each do |record|
      Delete::Execution.new(record, destination).call
      @harvest_report.increment_records_deleted!
    rescue StandardError => e
      Rails.logger.info "DeleteWorker: Delete Excecution error: #{e}" if defined?(Sidekiq)
    end
  end
end
