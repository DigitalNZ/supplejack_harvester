# frozen_string_literal: true

# Nightly removal of preprocess block output that has fallen out of the
# retention policy: each pipeline keeps its newest keep_latest runs. Unlike
# extraction folders (see ExtractionCleanupWorker), preprocess output has no
# owning database record, so cleanup here is keyed off the pipeline job that
# wrote each folder rather than a purge timestamp.
class PreProcessCleanupWorker
  include Sidekiq::Job
  include CleanupReport

  sidekiq_options retry: 0, queue: 'low_priority'

  # An orphan folder (no pipeline job row) is only swept once it has sat
  # untouched this long, so the sweep can never race a run whose row was
  # only just created.
  ORPHAN_WINDOW = 1.day

  def initialize
    @policy = PreProcessRetentionPolicy.load
    @report = []
    @examined = 0
    @swept = 0
  end

  # Pass a pipeline id to clean one pipeline only (console use); nil sweeps
  # everything. Returns the logged lines so a console run can `puts` them.
  def perform(pipeline_id = nil)
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
      id = pipeline_job.id
      sweep(PreProcess::Output.job_folder(id), "pipeline_job=#{id}")
    rescue StandardError => e
      report_failure("pipeline_job=#{id}", e)
    end
  end

  def sweep_orphans(ids_on_disk)
    (ids_on_disk - PipelineJob.where(id: ids_on_disk).pluck(:id)).each do |pipeline_job_id|
      folder = PreProcess::Output.job_folder(pipeline_job_id)
      next unless File.mtime(folder) < ORPHAN_WINDOW.ago

      sweep(folder, "pipeline_job=#{pipeline_job_id} (orphan)")
    rescue StandardError => e
      report_failure("pipeline_job=#{pipeline_job_id}", e)
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

  def summary_message
    return "finished would_sweep=#{@examined} dry_run=true" if @policy.dry_run?

    "finished swept=#{@swept} examined=#{@examined} dry_run=false"
  end

  def log_tag
    '[preprocess_cleanup]'
  end
end
