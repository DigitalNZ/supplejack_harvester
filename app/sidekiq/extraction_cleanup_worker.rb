# frozen_string_literal: true

# Nightly removal of extracted data that has aged out of the retention policy.
# Folders are deleted; the job rows stay so run history survives.
class ExtractionCleanupWorker
  include Sidekiq::Job

  sidekiq_options retry: 0, queue: 'low_priority'

  def perform
    @policy = ExtractionRetentionPolicy.load
    @examined = 0
    @examined_bytes = 0
    @purged = 0
    @purged_bytes = 0

    purge_extraction_jobs

    log(summary_message)
  end

  private

  # The `rescue` below is attached to this `do...end` block, not to a method -
  # Ruby allows that without a `begin`. It keeps one bad folder from aborting
  # the batch: a failed purge leaves purged_at null so the next run retries it.
  def purge_extraction_jobs
    ExtractionJob.purge_candidates(@policy).each do |job|
      bytes = examine(job)
      next if @policy.dry_run?

      purge(job, bytes)
    rescue StandardError => e
      report_failure(job, e)
    end
  end

  # purge! backs out with false when the job turned busy mid-batch; that skip
  # is logged but never counted as a purge.
  def purge(job, bytes)
    if job.purge!
      record_purge(bytes)
    else
      log("skipped busy extraction_job=#{job.id}")
    end
  end

  # Logs and tallies every candidate, whether or not it ends up purged. This is
  # what lets a dry run report how much *would* be freed.
  def examine(job)
    bytes = job.extraction_folder_size_in_bytes
    @examined += 1
    @examined_bytes += bytes
    log("extraction_job=#{job.id} definition=#{job.extraction_definition_id} " \
        "created_at=#{job.created_at.iso8601} index=#{job.extraction_index} bytes=#{bytes}")
    bytes
  end

  # Only counted once the folder is actually gone, so the summary never claims
  # a purge or freed bytes that didn't happen.
  def record_purge(bytes)
    @purged += 1
    @purged_bytes += bytes
  end

  def report_failure(job, error)
    Rails.logger.error("[extraction_cleanup] failed extraction_job=#{job.id} #{error.class}: #{error.message}")
    Airbrake.notify(error)
  end

  def summary_message
    return "finished examined=#{@examined} would_free_bytes=#{@examined_bytes} dry_run=true" if @policy.dry_run?

    "finished purged=#{@purged} bytes=#{@purged_bytes} examined=#{@examined} dry_run=false"
  end

  def log(message)
    Rails.logger.info("[extraction_cleanup]#{@policy.dry_run? ? ' [dry run]' : ''} #{message}")
  end
end
