# frozen_string_literal: true

# Nightly removal of extracted data that has aged out of the retention policy.
# Folders are deleted; the job rows stay so run history survives.
#
# See docs/superpowers/specs/2026-07-31-extracted-data-lifecycle-policy-design.md
class ExtractionCleanupWorker
  include Sidekiq::Job

  sidekiq_options retry: 0, queue: 'low_priority'

  def perform
    @policy = ExtractionLifecyclePolicy.load
    @examined = 0
    @examined_bytes = 0
    @purged = 0
    @purged_bytes = 0
    @preprocess_examined = 0
    @preprocess_swept = 0

    purge_extraction_jobs
    sweep_preprocess_folders

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

      job.purge!
      record_purge(bytes)
    rescue StandardError => e
      report_failure(job, e)
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

  # Preprocess output has no owning database record, so cleanup is keyed off
  # the pipeline job that wrote each folder rather than a purge timestamp.
  #
  # The rescue is attached to this do...end block, not a method - same trick
  # as purge_extraction_jobs. It covers the sweepability check as well as the
  # removal: a folder that vanishes between Dir.children and the mtime stat
  # (ENOENT) or one FileUtils.rm_r can't remove (e.g. permissions) must not
  # abort the batch or swallow the summary log for the rest of the run.
  def sweep_preprocess_folders
    PreProcess::Output.pipeline_job_ids_on_disk.each do |pipeline_job_id|
      folder = PreProcess::Output.job_folder(pipeline_job_id)
      next unless sweepable?(pipeline_job_id, folder)

      @preprocess_examined += 1
      log("preprocess pipeline_job=#{pipeline_job_id}")
      remove_preprocess_folder(folder) unless @policy.dry_run?
    rescue StandardError => e
      report_preprocess_failure(pipeline_job_id, e)
    end
  end

  def remove_preprocess_folder(folder)
    FileUtils.rm_r(folder)
    @preprocess_swept += 1
  end

  # A folder whose pipeline job row no longer exists is an orphan, only swept
  # once it has sat untouched for a day so this can never race a run whose
  # row was only just created. Otherwise the owning job decides: a terminal
  # status old enough to clear min_age_cutoff is swept as normal, and a job
  # that never reaches a terminal status (nothing in the app ever sets
  # status to errored, so a crashed run stays "running" forever) is swept
  # once it clears the much larger max_age_cutoff regardless of status, so
  # a dead run's output doesn't linger indefinitely.
  #
  # Checks the status column directly rather than PipelineJob#finished? --
  # that method is overridden to track whether every harvest report's load
  # workers have completed (see LoadWorker#job_end), a different question
  # from whether the job itself has stopped running.
  def sweepable?(pipeline_job_id, folder)
    pipeline_job = PipelineJob.find_by(id: pipeline_job_id)
    return File.mtime(folder) < 1.day.ago if pipeline_job.nil?

    finished_and_old?(pipeline_job) || past_max_age?(pipeline_job)
  end

  def finished_and_old?(pipeline_job)
    pipeline_job.status.in?(%w[cancelled completed errored]) && pipeline_job.created_at < @policy.min_age_cutoff
  end

  def past_max_age?(pipeline_job)
    pipeline_job.created_at < @policy.max_age_cutoff
  end

  def report_preprocess_failure(pipeline_job_id, error)
    Rails.logger.error(
      "[extraction_cleanup] failed preprocess pipeline_job=#{pipeline_job_id} #{error.class}: #{error.message}"
    )
    Airbrake.notify(error)
  end

  def summary_message
    if @policy.dry_run?
      "finished examined=#{@examined} would_free_bytes=#{@examined_bytes} dry_run=true " \
        "preprocess_would_sweep=#{@preprocess_examined}"
    else
      "finished purged=#{@purged} bytes=#{@purged_bytes} examined=#{@examined} dry_run=false " \
        "preprocess_swept=#{@preprocess_swept}"
    end
  end

  def log(message)
    Rails.logger.info("[extraction_cleanup]#{@policy.dry_run? ? ' [dry run]' : ''} #{message}")
  end
end
