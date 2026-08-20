# frozen_string_literal: true

class PipelineJob < ApplicationRecord
  include Job
  include RunConfiguration

  serialize :harvest_definitions_to_run, type: Array, coder: YAML

  belongs_to :pipeline
  belongs_to :extraction_job, optional: true
  belongs_to :destination
  belongs_to :schedule, optional: true
  belongs_to :launched_by, class_name: 'User', optional: true

  has_many :harvest_reports, dependent: :destroy
  has_many :harvest_jobs, dependent: :destroy
  belongs_to :automation_step, optional: true

  enum :page_type, { all_available_pages: 0, set_number: 1 }

  # How long an unfinished run is protected from the preprocess sweep. A
  # safety window, not a retention choice, so it lives in code, not config.
  PREPROCESS_WRITING_WINDOW = 1.day

  with_options if: :set_number? do
    validates :pages, presence: true
  end

  # Preprocess output folders whose run has fallen outside the newest
  # keep_latest runs of its pipeline. ids_on_disk comes from
  # PreProcess::Output.pipeline_job_ids_on_disk, so the ranking only ever
  # considers runs that still have output: keep_latest means "the newest N
  # folders", not "the newest N runs". Plain Ruby rather than a SQL window
  # function because the set is at most a few folders per pipeline once the
  # sweep is live.
  def self.preprocess_sweep_candidates(policy, ids_on_disk, pipeline_id: nil)
    scope = where(id: ids_on_disk)
    scope = scope.where(pipeline_id:) if pipeline_id

    scope
      .order(created_at: :desc, id: :desc)
      .group_by(&:pipeline_id)
      .values
      .flat_map { |jobs| jobs.drop(policy.keep_latest) }
      .reject(&:maybe_still_writing?)
  end

  # Check if this job is part of an automation
  def from_automation?
    automation_step.present?
  end

  # Whether this run might still be writing preprocess output. Checks the
  # status column directly, not #finished? -- that method is overridden to
  # track whether every harvest report's load workers have completed, a
  # different question. Status alone cannot be trusted either: nothing ever
  # moves a crashed run to errored, and a preprocess-only pipeline never
  # completes, so "unfinished" stops protecting a run once it is a day old.
  def maybe_still_writing?
    !status.in?(Job::FINISHED_STATUSES) && created_at > PREPROCESS_WRITING_WINDOW.ago
  end

  # Called by this run's blocks as each of them finishes - see RunCompletion for why the
  # run has to work this out for itself.
  def finish_if_complete
    completion = RunCompletion.new(self)
    return unless completion.finished?

    completion.errored? ? errored! : completed!
    update(end_time: Time.zone.now) if end_time.blank?
  end

  # Trigger the next step in the automation if this job is from an automation and has completed
  def trigger_next_automation_step
    return unless from_automation? && harvest_reports.all?(&:completed?)

    # Find the current step and the next step in the automation
    current_step = automation_step
    next_step = current_step.next_step

    # If there's a next step, continue the automation
    return if next_step.blank?

    AutomationWorker.perform_async_with_priority(job_priority, current_step.automation_id, next_step.id)
  end

  # Step the processing chain forward once a block has finished. Creates the
  # next block's HarvestJob and enqueues it; when the chain is exhausted it falls
  # through to the enrichment jobs (preserving the legacy end-of-harvest behaviour).
  def advance_to_next_block(completed_definition)
    reload
    return if cancelled?

    next_definition = next_block_to_run(completed_definition)
    return enqueue_enrichment_jobs(completed_definition.name) if next_definition.blank?

    job = create_next_block_job(next_definition)
    HarvestWorker.perform_async_with_priority(job_priority, job.id) if job.present?
  end

  def enqueue_enrichment_jobs(job_id)
    return unless should_queue_enrichments?

    pipeline.enrichments.each do |enrichment|
      next unless should_queue_enrichment?(enrichment)

      enrichment_job = HarvestJob.create(
        harvest_definition: enrichment, pipeline_job: self, target_job_id: job_id
      )

      HarvestWorker.perform_async_with_priority(job_priority, enrichment_job.id)
    end
  end

  # How this run is named wherever one has to be picked out of a list: the request
  # preview's run selector, the Run modal's input choices, and the dropdown that runs a
  # single block against an earlier run's pre-processed data.
  def run_label
    "Job ##{id} - #{created_at.strftime('%-d %b %Y, %H:%M')}"
  end

  # The next block of the chain that this run is actually configured to run. Blocks
  # the user unticked are stepped over: their data comes from whatever the following
  # block's input nominates (see RunConfiguration#validate_chain_inputs).
  def next_block_to_run(completed_definition)
    pipeline.ordered_blocks
            .where(position: (completed_definition.position + 1)..)
            .find { |definition| should_run?(definition.id) }
  end

  # Which run's pre-processed output this block reads from. Its own, unless the user
  # nominated an earlier run's data in the Run modal.
  def preprocess_source_job_id(definition)
    input = input_for(definition)
    return id unless input.preprocess_output?
    return input.pipeline_job_id unless input.latest?

    latest_source_job_id(definition) || id
  end

  def harvest_report
    harvest_reports.find_by(kind: 'harvest')
  end

  def finished?
    harvest_reports.all?(&:finished?)
  end

  # Whether this enrichment is one this run still has to queue - asked by RunCompletion as
  # well as when they are queued.
  def should_queue_enrichment?(enrichment)
    enrichment_id = enrichment.id

    should_run?(enrichment_id) && enrichment.ready_to_run? &&
      !harvest_jobs.exists?(pipeline_job_id: id, harvest_definition_id: enrichment_id)
  end

  private

  # For a schedule-driven run, 'latest' means the most recent *other* run of this
  # pipeline that has output for the position this block consumes.
  def latest_source_job_id(definition)
    pipeline.pipeline_jobs
            .where(id: PreProcess::Output.pipeline_job_ids_with_output(definition.position - 1))
            .where.not(id:)
            .order(created_at: :desc)
            .pick(:id)
  end

  # The transformation-completion gate can fire more than once for a single
  # block under concurrent workers. The unique index on
  # (pipeline_job_id, harvest_definition_id) turns the losing caller's insert
  # into RecordNotUnique instead of a duplicate job; it must enqueue nothing.
  def create_next_block_job(next_definition)
    HarvestJob.create!(harvest_definition: next_definition, pipeline_job: self)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def should_queue_enrichments?
    reload
    !cancelled? && pipeline.enrichments.present? && harvest_completed?
  end

  def harvest_completed?
    return true if harvest_report.blank?

    harvest_report.completed?
  end

  def should_run?(id)
    harvest_definitions_to_run.map(&:to_i).include?(id)
  end
end
