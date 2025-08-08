# frozen_string_literal: true

module JobsHelper
  STATUS_TO_TEXT = {
    'queued' => 'Waiting in queue...',
    'running' => 'Running...',
    'errored' => 'An error occured',
    'cancelled' => 'Cancelled',
    'completed' => 'Completed'
  }.freeze

  # Returns the human readable text for the status of a given job
  #
  # @return String
  def job_status_text(job)
    return "Running #{job.kind} job..." if job.running? && job.instance_of?(ExtractionJob)

    STATUS_TO_TEXT[job.status]
  end

  def job_start_time(job)
    job.start_time.present? ? job.start_time.to_fs(:light) : '-'
  end

  def job_end_time(job)
    job.end_time.present? ? job.end_time.to_fs(:light) : '-'
  end

  def job_duration(job)
    job_duration_seconds(job&.duration_seconds)
  end

  def job_duration_seconds(seconds)
    return '-' if seconds.nil?

    ActiveSupport::Duration.build(seconds).inspect
  end

  def job_badge_classes(report)
    class_names(
      'badge',
      'bg-primary': report&.status == 'completed',
      'bg-secondary': %w[running queued cancelled].include?(report&.status)
    )
  end

  def job_status_label(report, job)
    return job.cancelled? ? 'Cancelled' : 'Waiting' if report.nil?

    report.status.capitalize
  end

  def job_launched_by_label(pipeline_job)
    if pipeline_job.schedule.present?
      'Schedule'
    elsif pipeline_job.automation_step.present?
      link_to 'Automation', automation_path(pipeline_job.automation_step.automation)
    else
      pipeline_job.launched_by&.username
    end
  end

  def job_started_at_label(report, job)
    if report&.harvest_job&.extraction_job.present? && report&.extraction_start_time.present?
      report.extraction_start_time.strftime('%H:%M %d/%m/%y')
    else
      job.start_time.strftime('%H:%M %d/%m/%y')
    end
  end

  def job_priority_label(report)
    if report.nil?
      ''
    elsif report.harvest_job.present?
      report.harvest_job.pipeline_job.job_priority&.presence&.humanize || 'No priority'
    else
      'No priority'
    end
  end
end
