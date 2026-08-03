# frozen_string_literal: true

# Nightly removal of preprocess block output that has aged out of the
# retention policy. Unlike extraction folders (see ExtractionCleanupWorker),
# preprocess output has no owning database record, so cleanup here is keyed
# off the pipeline job that wrote each folder rather than a purge timestamp.
#
# See docs/superpowers/specs/2026-07-31-extracted-data-lifecycle-policy-design.md
class PreProcessCleanupWorker
  include Sidekiq::Job

  sidekiq_options retry: 0, queue: 'low_priority'

  def perform
    @policy = ExtractionLifecyclePolicy.load
    @examined = 0
    @swept = 0

    sweep_preprocess_folders

    log(summary_message)
  end

  private

  # The rescue is attached to this do...end block, not a method - it keeps
  # one bad folder from aborting the batch. It covers the sweepability check
  # as well as the removal: a folder that vanishes between Dir.children and
  # the mtime stat (ENOENT), or one FileUtils.rm_r can't remove (e.g.
  # permissions), must not abort the run or swallow the summary log.
  def sweep_preprocess_folders
    PreProcess::Output.pipeline_job_ids_on_disk.each do |pipeline_job_id|
      folder = PreProcess::Output.job_folder(pipeline_job_id)
      next unless sweepable?(pipeline_job_id, folder)

      @examined += 1
      log("pipeline_job=#{pipeline_job_id}")
      remove_folder(folder) unless @policy.dry_run?
    rescue StandardError => e
      report_failure(pipeline_job_id, e)
    end
  end

  # Only counted once the folder is actually gone, so the summary never
  # claims a sweep that didn't happen.
  def remove_folder(folder)
    FileUtils.rm_r(folder)
    @swept += 1
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
    pipeline_job.status.in?(Job::FINISHED_STATUSES) && pipeline_job.created_at < @policy.min_age_cutoff
  end

  def past_max_age?(pipeline_job)
    pipeline_job.created_at < @policy.max_age_cutoff
  end

  def report_failure(pipeline_job_id, error)
    Rails.logger.error(
      "[preprocess_cleanup] failed pipeline_job=#{pipeline_job_id} #{error.class}: #{error.message}"
    )
    Airbrake.notify(error)
  end

  def summary_message
    return "finished would_sweep=#{@examined} dry_run=true" if @policy.dry_run?

    "finished swept=#{@swept} examined=#{@examined} dry_run=false"
  end

  def log(message)
    Rails.logger.info("[preprocess_cleanup]#{@policy.dry_run? ? ' [dry run]' : ''} #{message}")
  end
end
