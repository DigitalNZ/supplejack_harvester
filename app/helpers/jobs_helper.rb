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

  # Short enough to sit beside the time the job started: 2h 40m, 9m 57s, 5s. An hour-long
  # run leaves its seconds out - at that length they are noise rather than detail.
  def job_duration_seconds_short(seconds)
    hours   = seconds / 3_600
    minutes = (seconds % 3_600) / 60
    seconds %= 60

    return "#{hours}h #{minutes}m" if hours.positive?
    return "#{minutes}m #{seconds}s" if minutes.positive?

    "#{seconds}s"
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

  # When a job started and how long it took, as the one column the design gives them. A
  # queued job has started at neither, and a running one has no duration yet, so the two
  # are joined rather than interpolated: what there is of it is shown without a separator
  # dangling off the end.
  def job_started_and_duration(report, job)
    parts = [job_started_at_label(report, job), job_duration(report, format: :short)]

    safe_join(parts.compact_blank, ' · ')
  end

  # The line under a pipeline's name in the jobs table: where the job wrote, and who set
  # it going. Run by is a link when a schedule or an automation did it, so the parts are
  # joined rather than interpolated, and a job nobody is recorded as running is left as
  # its destination alone rather than trailing a 'Run by' with nothing after it.
  def job_source_line(job)
    run_by = job_launched_by_label(job)
    parts = [job.destination.name]
    parts << safe_join(['Run by ', run_by]) if run_by.present?

    safe_join(parts, ' · ')
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
end
