# frozen_string_literal: true

# Whether a run is over.
#
# Nothing is in a position to tell it: PipelineWorker returns as soon as it has started the
# first block, and from there the blocks start each other as they finish, so no single
# worker knows whether it was the last. This answers the two questions that decide it -
# has every block that started finished, and can anything else still start.
class RunCompletion
  def initialize(pipeline_job)
    @pipeline_job = pipeline_job
  end

  TERMINAL_STATUSES = %w[cancelled completed errored].freeze

  # Deliberately the status column rather than PipelineJob#finished?, which reads the
  # reports and so is true the moment the blocks are done - the very thing being decided
  # here.
  def finished?
    return false if @pipeline_job.status.in?(TERMINAL_STATUSES) || reports.empty?
    return false unless reports.all?(&:finished?)

    !more_blocks_coming?
  end

  # A run whose blocks did not all get there.
  def errored?
    reports.any? { |report| report.status == 'errored' }
  end

  private

  # Read from the database rather than from whatever the run is already holding.
  # HarvestReport#report_to_pipeline_job asks this question once per status it writes, and
  # all four of those calls go through the same report's `pipeline_job` - so the first of
  # them loads the reports onto it and the rest would be answered from that cache, seeing
  # a stale copy of the very report whose status just changed. The last status of the last
  # block is the one that ends a run, so that is precisely the call that has to be right.
  #
  # Remembered per instance: one RunCompletion answers about one moment.
  def reports
    @reports ||= @pipeline_job.harvest_reports.reload.to_a
  end

  # Two things start a block: the chain steps forward as each one finishes, and the
  # enrichments are queued once the harvest has completed.
  def more_blocks_coming?
    chain_block_pending? || enrichments_pending?
  end

  def chain_block_pending?
    last_started = started_definitions.reject(&:enrichment?).max_by(&:position)
    return false if last_started.blank?

    @pipeline_job.next_block_to_run(last_started).present?
  end

  # Enrichments are only ever queued off the back of a completed harvest, so a run of
  # pre-processing blocks alone has none coming however many are ticked.
  def enrichments_pending?
    return false unless @pipeline_job.harvest_report&.completed?

    @pipeline_job.pipeline.enrichments.any? { |enrichment| @pipeline_job.should_queue_enrichment?(enrichment) }
  end

  def started_definitions
    @pipeline_job.harvest_jobs.includes(:harvest_definition).filter_map(&:harvest_definition)
  end
end
