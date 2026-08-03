# frozen_string_literal: true

# Shared by PipelineJob and Schedule: the per-block "what runs, and what feeds it"
# configuration that the Run modal and the schedule form post.
#
# block_settings is the canonical form. harvest_definitions_to_run is kept in sync
# from it on save so that every existing reader (PipelineWorker, PipelineJob#should_run?,
# the jobs table, the schedules index) keeps working untouched, and so that callers
# which still post only the flat fields (Api::PipelineJobsController, automations,
# schedules created before this change) keep working too - see RunSettings.legacy.
module RunConfiguration
  extend ActiveSupport::Concern

  included do
    serialize :block_settings, type: Hash, coder: YAML

    before_validation :derive_harvest_definitions_to_run
    validate :validate_chain_inputs
  end

  # Normalised on the way in, so what is stored is always plain hashes of booleans
  # and canonical input strings. Params reach here as HashWithIndifferentAccess,
  # which Psych's safe dump refuses to serialize.
  def block_settings=(value)
    super(RunSettings.new(value).to_h)
  end

  # Not memoised on purpose: workers reload these records mid-flight, and a stale
  # memo here would silently answer questions about the previous state.
  def run_settings
    settings = RunSettings.new(block_settings)
    return settings unless settings.empty?

    RunSettings.legacy(
      definitions_to_run: harvest_definitions_to_run,
      extraction_job_id: legacy_extraction_job_id,
      non_enrichment_ids: pipeline&.ordered_blocks&.ids || []
    )
  end

  def input_for(definition)
    run_settings.input_for(definition.id)
  end

  # The ExtractionJob whose documents this block should transform instead of
  # extracting afresh, or nil to extract. Enrichments always extract: they iterate
  # records out of the destination API, so there is nothing to reuse.
  def existing_extraction_job_for(definition)
    return if definition.enrichment?

    input = input_for(definition)
    return unless input.extraction_job?

    ExtractionJob.find_by(id: input.extraction_job_id)
  end

  private

  # Schedule has no extraction_job_id column; PipelineJob does.
  def legacy_extraction_job_id
    respond_to?(:extraction_job_id) ? extraction_job_id : nil
  end

  def derive_harvest_definitions_to_run
    settings = RunSettings.new(block_settings)
    return if settings.empty?

    self.harvest_definitions_to_run = settings.definition_ids_to_run
  end

  def validate_chain_inputs
    settings = RunSettings.new(block_settings)
    return if pipeline.blank? || settings.empty?

    ChainInputs.new(pipeline:, settings:).errors.each do |message|
      errors.add(:block_settings, message)
    end
  end
end
