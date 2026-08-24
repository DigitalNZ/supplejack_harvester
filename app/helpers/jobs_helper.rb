# frozen_string_literal: true

module JobsHelper
  include JobReportsHelper

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

  def job_status_badge(report, job)
    status_badge(report&.status || job.status)
  end

  def status_badge(status)
    tag.span(class: job_badge_classes(status)) do
      status&.capitalize
    end
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
    if (schedule = pipeline_job.schedule.presence)
      link_to 'Schedule', schedule_path(schedule)
    elsif (automation_step = pipeline_job.automation_step.presence)
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

  def job_priority_label(job)
    return '' unless job

    job.job_priority.presence&.humanize || 'Default'
  end

  # The jobs of one pipeline. pipeline_id rides along in the query as well as the path,
  # because the filter form on that page posts it to the global jobs list.
  def jobs_filter_url(pipeline)
    "#{pipeline_pipeline_jobs_path(pipeline)}?pipeline_id=#{pipeline.id}"
  end

  # The filters carry no label beside them, so each one says what it filters. Choosing
  # 'all' submits nothing rather than a sentinel the controller has to know about.
  # Every option says 'Run by', not just the default: a username on its own would not
  # say what it is filtering once it is the one selected.
  def user_opts
    who = User.distinct.pluck(:username).compact.sort.unshift('Schedule')

    [['Run by: anyone', '']] + who.map { |name| ["Run by: #{name}", name] }
  end

  def status_opts
    [['All statuses', '']] + %w[Queued Cancelled Completed Running Errored]
  end

  def dest_opts
    [['All destinations', '']] + Destination.distinct.pluck(:name).compact
  end
end
