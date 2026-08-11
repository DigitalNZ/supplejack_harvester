# frozen_string_literal: true

# Nightly removal of extracted data that has aged out of the retention policy.
# Folders are deleted; the job rows stay so run history survives.
class ExtractionCleanupWorker
  include Sidekiq::Job
  include CleanupReport

  sidekiq_options retry: 0, queue: 'low_priority'

  # Pass a pipeline id to clean one pipeline only (console use); nil sweeps
  # everything. Returns the logged lines so a console run can `puts` them.
  def perform(pipeline_id = nil)
    reset_state

    log_scope(pipeline_id)
    purge_extraction_jobs(pipeline_id)
    log_batch_limit_reached
    log(summary_message)

    @report.join("\n")
  end

  private

  def reset_state
    @policy = ExtractionRetentionPolicy.load
    @report = []
    @examined = 0
    @examined_bytes = 0
    @purged = 0
    @purged_bytes = 0
  end

  # The `rescue` below is attached to this `do...end` block, not to a method -
  # Ruby allows that without a `begin`. It keeps one bad folder from aborting
  # the batch: a failed purge leaves purged_at null so the next run retries it.
  def purge_extraction_jobs(pipeline_id)
    ExtractionJob.purge_candidates(@policy, pipeline_id:).each do |job|
      bytes = examine(job)
      next if @policy.dry_run?

      purge(job, bytes)
    rescue StandardError => e
      report_failure("extraction_job=#{job.id}", e)
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

  def summary_message
    return "finished examined=#{@examined} would_free_bytes=#{@examined_bytes} dry_run=true" if @policy.dry_run?

    "finished purged=#{@purged} bytes=#{@purged_bytes} examined=#{@examined} dry_run=false"
  end

  # A capped batch looks complete in the report but is not: more candidates
  # may still qualify next run. Flag it so a reader doesn't mistake the batch
  # for the full picture.
  def log_batch_limit_reached
    return unless @examined == @policy.batch_limit

    log("batch_limit reached (#{@policy.batch_limit}); more may qualify")
  end

  def log_tag
    '[extraction_cleanup]'
  end
end
