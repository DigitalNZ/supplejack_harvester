# frozen_string_literal: true

# Used to store information about a Harvest Job
class HarvestJob < ApplicationRecord
  include Job

  belongs_to :pipeline_job
  belongs_to :harvest_definition
  belongs_to :extraction_job, optional: true
  has_one    :harvest_report, dependent: nil

  delegate :extraction_definition, to: :harvest_definition
  delegate :transformation_definition, to: :harvest_definition

  PROCESSES = %w[TransformationWorker LoadWorker DeleteWorker].freeze

  after_create do
    self.name = "#{id}_#{harvest_definition.kind}"
    save!
  end

  def cancel
    extraction_job.cancelled! unless extraction_job.completed?
    cancel_sidekiq_workers
    cancelled!
  end

  def execute_delete_previous_records
    return unless flush_previous_records?

    DeletePreviousRecords::Execution.new(harvest_definition.source_id, name, pipeline_job.destination).call
  end

  # Runs after this job's extraction completes. A preprocess block must not
  # queue enrichments — the harvest it enriches has not run yet.
  def trigger_following_processes
    pipeline_job.enqueue_enrichment_jobs(name) unless harvest_definition.preprocess?
    execute_delete_previous_records
    advance_chain
  end

  # A pre-processing block exists to feed the next one, so the chain steps forward when it
  # finishes - which for such a block means its transformation finishing, since it queues
  # no loads or deletes.
  #
  # Either worker can be the one to see that happen: normally the last transformation
  # worker does, but when they all finish while the extraction is still running they stand
  # aside and the extraction worker completes the report instead. Asking the report rather
  # than the caller means the chain moves on in both cases, and never before the block is
  # actually done. PipelineJob#advance_to_next_block is idempotent, so being asked twice
  # costs nothing.
  # Only when there is a block to advance to: with none, PipelineJob#advance_to_next_block
  # falls through to the enrichments, and a pre-processing block finishing is no reason to
  # enrich - the harvest it would enrich has not run.
  def advance_chain
    return unless harvest_definition.preprocess?
    return unless harvest_report&.reload&.transformation_completed?
    return if pipeline_job.next_block_to_run(harvest_definition).blank?

    pipeline_job.advance_to_next_block(harvest_definition)
  end

  private

  # A block that loads at a non-zero priority writes to its own fragment on records owned
  # by other sources, so it must never flush. FlushOldRecordsWorker in the API matches on
  # 'fragments.source_id' and 'fragments.priority': 0 without wrapping them in $elemMatch,
  # so the priority clause is satisfied by the ORIGINAL harvest's primary fragment -
  # flushing on such a block marks the whole record deleted rather than dropping this
  # block's fragment.
  def flush_previous_records?
    return false unless harvest_definition.harvest?
    return false unless harvest_definition.priority.zero?
    return false unless pipeline_job.delete_previous_records? && !pipeline_job.cancelled?

    harvest_report.ready_to_delete_previous_records?
  end

  # The order of arguments is important to sidekiq workers as they do not support keyword arguments
  # If the order of arguments change in the TransformationWorker, LoadWorker, or DeleteWorker
  # That change will need to be reflected here
  # args[0] is assumed to be the harvest_job_id

  # :reek:FeatureEnvy
  # This reek has been ignored as the job referred here is the Sidekiq job.
  def cancel_sidekiq_workers
    queue = Sidekiq::Queue.new

    queue.each do |job|
      job.delete if PROCESSES.include?(job.klass) && job.args[0] == id
    end
  end
end
