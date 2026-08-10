# frozen_string_literal: true

# Nightly removal of preprocess block output that has fallen out of the
# retention policy: each pipeline keeps its newest keep_latest runs. Unlike
# extraction folders (see ExtractionCleanupWorker), preprocess output has no
# owning database record, so cleanup here is keyed off the pipeline job that
# wrote each folder rather than a purge timestamp.
class PreProcessCleanupWorker
  include Sidekiq::Job

  sidekiq_options retry: 0, queue: 'low_priority'

  # An orphan folder (no pipeline job row) is only swept once it has sat
  # untouched this long, so the sweep can never race a run whose row was
  # only just created.
  ORPHAN_WINDOW = 1.day

  # Pass a pipeline id to clean one pipeline only (console use); nil sweeps
  # everything. Returns the logged lines so a console run can `puts` them.
  def perform(pipeline_id = nil)
    @policy = PreProcessRetentionPolicy.load
    @report = []
    @examined = 0
    @swept = 0

    log_scope(pipeline_id)
    ids_on_disk = PreProcess::Output.pipeline_job_ids_on_disk
    sweep_out_ranked(ids_on_disk, pipeline_id)
    # Orphans belong to no pipeline, so a scoped run never touches them.
    sweep_orphans(ids_on_disk) unless pipeline_id
    log(summary_message)

    @report.join("\n")
  end

  private

  # Each rescue is attached to its loop block, not a method - one bad folder
  # (vanished between listing and stat, undeletable, ...) must not abort the
  # batch or swallow the summary log.
  def sweep_out_ranked(ids_on_disk, pipeline_id)
    PipelineJob.preprocess_sweep_candidates(@policy, ids_on_disk, pipeline_id:).each do |pipeline_job|
      sweep(PreProcess::Output.job_folder(pipeline_job.id), "pipeline_job=#{pipeline_job.id}")
    rescue StandardError => e
      report_failure(pipeline_job.id, e)
    end
  end

  def sweep_orphans(ids_on_disk)
    (ids_on_disk - PipelineJob.where(id: ids_on_disk).pluck(:id)).each do |pipeline_job_id|
      folder = PreProcess::Output.job_folder(pipeline_job_id)
      next unless File.mtime(folder) < ORPHAN_WINDOW.ago

      sweep(folder, "pipeline_job=#{pipeline_job_id} (orphan)")
    rescue StandardError => e
      report_failure(pipeline_job_id, e)
    end
  end

  def sweep(folder, label)
    @examined += 1
    log(label)
    remove_folder(folder) unless @policy.dry_run?
  end

  # Only counted once the folder is actually gone, so the summary never
  # claims a sweep that didn't happen.
  def remove_folder(folder)
    FileUtils.rm_r(folder)
    @swept += 1
  end

  def report_failure(pipeline_job_id, error)
    line = "failed pipeline_job=#{pipeline_job_id} #{error.class}: #{error.message}"
    @report << line
    Rails.logger.error("[preprocess_cleanup] #{line}")
    Airbrake.notify(error)
  end

  def summary_message
    return "finished would_sweep=#{@examined} dry_run=true" if @policy.dry_run?

    "finished swept=#{@swept} examined=#{@examined} dry_run=false"
  end

  # find, not find_by: a typo'd id in the console should raise, not silently
  # sweep nothing.
  def log_scope(pipeline_id)
    return unless pipeline_id

    log("scoped to pipeline=#{pipeline_id} (#{Pipeline.find(pipeline_id).name})")
  end

  # Report lines carry the dry-run marker; the worker tag is only added on the
  # logger line, where the reader lacks the console's context.
  def log(message)
    line = "#{'[dry run] ' if @policy.dry_run?}#{message}"
    @report << line
    Rails.logger.info("[preprocess_cleanup] #{line}")
  end
end
