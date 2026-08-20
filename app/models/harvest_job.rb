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
  delegate :load_kind, to: :harvest_definition

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

  # Runs after this job's extraction completes.
  def trigger_following_processes
    pipeline_job.enqueue_enrichment_jobs(name) if enriches_when_finished?
    execute_delete_previous_records
    advance_chain
  end

  # Whether the enrichments follow this block finishing. A pre-processing block feeds the next
  # block instead: the harvest its run's enrichments would enrich has not run when it finishes.
  def enriches_when_finished?
    !harvest_definition.preprocess?
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

  # The enrichments this run has to queue off the back of this block, asked by whichever
  # worker completed its report - the same reasoning as #advance_chain.
  #
  # #trigger_following_processes already asks on the extraction worker's behalf, but that
  # runs while this block's transformation workers are still going, so the report is not
  # complete yet and there is nothing to queue. Normally the last load worker asks again
  # once it is (LoadWorker#job_end), and a harvest that loads records is carried that way.
  # One that loads none - the source answered, but no record matched the transformation's
  # selector - has no load worker to carry it, and its enrichments were never queued:
  # RunCompletion#enrichments_pending? then keeps the run on "running" for good, waiting
  # for a block that nothing will ever start.
  #
  # PipelineJob#enqueue_enrichment_jobs only queues an enrichment that has no job on this
  # run yet, so being asked from more than one route costs nothing.
  def queue_enrichments
    return unless enriches_when_finished?
    return unless harvest_report&.reload&.completed?

    pipeline_job.enqueue_enrichment_jobs(name)
  end

  # This block's last load finishing, asked by whichever worker saw it happen - all three of
  # them can be the one, so all three ask here. Load::Completion holds why that matters.
  def complete_load(report)
    Load::Completion.new(self, report).call
  end

  private

  def flush_previous_records?
    harvest_definition.harvest? && writes_primary_fragment? &&
      run_asked_to_flush? && harvest_report.ready_to_delete_previous_records?
  end

  def run_asked_to_flush?
    pipeline_job.delete_previous_records? && !pipeline_job.cancelled?
  end

  # Only a block replacing a source's own records may flush. A block writing its own
  # fragment onto records owned by other sources must not: FlushOldRecordsWorker in the API
  # matches 'fragments.source_id' and 'fragments.priority': 0 without wrapping either in
  # $elemMatch, so the priority clause is satisfied by the ORIGINAL harvest's primary
  # fragment, and flushing marks the whole record deleted rather than dropping this block's
  # fragment. The priority check is belt and braces: a block claiming to write the primary
  # fragment at a non-zero priority is misconfigured, and this is too destructive to guess at.
  def writes_primary_fragment?
    harvest_definition.load_kind == 'primary_fragment' && harvest_definition.load_priority.zero?
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
