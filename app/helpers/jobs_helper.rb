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
    job.start_time&.to_fs(:light) || '-'
  end

  def job_end_time(job)
    job.end_time&.to_fs(:light) || '-'
  end

  def job_duration(job, format: :long)
    seconds = job&.duration_seconds
    return '' unless seconds

    case format
    when :short
      job_duration_seconds_short(seconds)
    when :long
      job_duration_seconds(seconds)
    else
      raise "Unknown duration format #{format}"
    end
  end

  def job_duration_seconds(seconds)
    return '' unless seconds

    ActiveSupport::Duration.build(seconds).inspect
  end

  def job_duration_seconds_short(seconds)
    hours   = seconds / 3_600
    minutes = (seconds % 3_600) / 60
    seconds %= 60

    format('%<h>d:%<m>02d:%<s>02d', h: hours, m: minutes, s: seconds)
  end

  def job_badge_classes(status)
    class_names(
      'badge',
      'bg-primary': status == 'completed',
      'bg-secondary': %w[running queued cancelled].include?(status)
    )
  end

  def job_status_label(report, job)
    return job.cancelled? ? 'Cancelled' : 'Waiting' unless report

    report.status.capitalize
  end

  def job_launched_by_label(pipeline_job)
    automation_step = pipeline_job.automation_step
    if pipeline_job.schedule.present?
      'Schedule'
    elsif automation_step.present?
      link_to 'Automation', automation_path(automation_step.automation)
    else
      pipeline_job.launched_by&.username
    end
  end

  def job_started_at_label(report, job)
    if report&.harvest_job&.extraction_job.present? && report&.extraction_start_time.present?
      report&.extraction_start_time&.strftime('%H:%M %d/%m/%y')
    else
      job.start_time&.strftime('%H:%M %d/%m/%y')
    end
  end

  def job_priority_label(report)
    return '' unless report

    priority = report.harvest_job&.pipeline_job&.job_priority
    priority.presence&.humanize || 'No priority'
  end
end
