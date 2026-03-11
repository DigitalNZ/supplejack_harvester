# frozen_string_literal: true

module JobReportsHelper
  EXTRACTION_STATUS_TO_END_REASON = {
    cancelled: 'Cancelled',
    errored: 'Errored',
    completed: 'Completed',
    running: 'Running',
    queued: 'Not ended yet'
  }.freeze

  def extraction_end_reason(report)
    extraction_job = report&.harvest_job&.extraction_job
    return 'Unknown' unless extraction_job

    stop_condition_reason(extraction_job) ||
      extraction_job.error_message.presence ||
      extraction_status_reason(report)
  end

  def job_report_priority_label(report)
    job_priority_label(report&.harvest_job&.pipeline_job)
  end

  private

  def stop_condition_reason(extraction_job)
    stop_condition_name = extraction_job.stop_condition_name
    return if stop_condition_name.blank?

    condition_type = extraction_job.stop_condition_type == 'user' ? 'User stop condition' : 'System stop condition'
    "#{condition_type}: #{stop_condition_name}"
  end

  def extraction_status_reason(report)
    EXTRACTION_STATUS_TO_END_REASON.each do |status, reason|
      return reason if report.public_send(:"extraction_#{status}?")
    end

    'Unknown'
  end
end
