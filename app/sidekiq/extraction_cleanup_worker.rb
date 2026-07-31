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
    @purged = 0
    @bytes = 0

    purge_extraction_jobs

    log("finished purged=#{@purged} bytes=#{@bytes} dry_run=#{@policy.dry_run?}")
  end

  private

  def purge_extraction_jobs
    ExtractionJob.purge_candidates(@policy).each do |job|
      count(job)
      next if @policy.dry_run?

      job.purge!
    rescue StandardError => e
      Rails.logger.error("[extraction_cleanup] failed extraction_job=#{job.id} #{e.class}: #{e.message}")
    end
  end

  def count(job)
    bytes = job.extraction_folder_size_in_bytes
    @purged += 1
    @bytes += bytes
    log("extraction_job=#{job.id} definition=#{job.extraction_definition_id} " \
        "created_at=#{job.created_at.iso8601} index=#{job.extraction_index} bytes=#{bytes}")
  end

  def log(message)
    Rails.logger.info("[extraction_cleanup]#{@policy.dry_run? ? ' [dry run]' : ''} #{message}")
  end
end
