# frozen_string_literal: true

module JobsHelper
  # Returns the human readable text for the status of a given job
  #
  # @return String
  def job_status_text(job)
    if job.queued?
      'Waiting in queue...'
    elsif job.running?
      job.instance_of?(ExtractionJob) ? "Running #{job.kind} job..." : 'Running...'
    elsif job.errored?
      'An error occured'
    elsif job.cancelled?
      'Cancelled'
    elsif job.completed?
      return 'Triggered Successfully' if job.instance_of?(HarvestJob)
      'Completed'
    end
  end

  def job_start_time(job)
    job.start_time.present? ? job.start_time.to_fs(:light) : '-'
  end

  def job_end_time(job)
    job.end_time.present? ? job.end_time.to_fs(:light) : '-'
  end

  def job_duration(job)
    job_duration_seconds(job.duration_seconds)
  end

  def job_duration_seconds(seconds)
    return '-' if seconds.nil?

    ActiveSupport::Duration.build(seconds).inspect
  end
end
