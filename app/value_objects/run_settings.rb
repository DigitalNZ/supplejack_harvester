# frozen_string_literal: true

# Per-block run configuration for a PipelineJob or a Schedule: for every block of
# the pipeline, whether it runs and where it takes its input from.
#
# Stored shape (block_settings), keyed by harvest_definition id as a string:
#
#   { '12' => { 'run' => true, 'input' => 'fresh' },
#     '13' => { 'run' => false, 'input' => 'fresh' },
#     '14' => { 'run' => true, 'input' => 'preprocess_output:44' } }
#
# Runs created before this existed (and the API/automation paths, which still post
# the flat fields) have no block_settings, so #legacy builds an equivalent view
# from harvest_definitions_to_run + extraction_job_id. Every reader goes through
# this object, so there is one place that understands both shapes.
class RunSettings
  RUN = 'run'
  INPUT = 'input'

  # @param settings [Hash] the raw block_settings hash
  def initialize(settings = {})
    @settings = normalize(settings)
  end

  # The old flat fields expressed as per-block settings. extraction_job_id was a
  # single field applied to every non-enrichment block, which is exactly what this
  # reproduces - see HarvestWorker#child_perform before this change.
  def self.legacy(definitions_to_run:, extraction_job_id: nil, non_enrichment_ids: [])
    input = extraction_job_id.present? ? "#{BlockInput::EXTRACTION_JOB}:#{extraction_job_id}" : BlockInput::FRESH

    settings = definitions_to_run.to_a.compact_blank.index_with do |id|
      { RUN => true, INPUT => non_enrichment_ids.map(&:to_s).include?(id.to_s) ? input : BlockInput::FRESH }
    end

    new(settings)
  end

  # What the Run modal starts on: run every block that can run, each on its own
  # default input. Matches the pre-existing modal, which ticked every ready block.
  def self.default_for(pipeline)
    settings = pipeline.harvest_definitions.select(&:ready_to_run?).to_h do |definition|
      [definition.id.to_s, { RUN => true, INPUT => BlockInput::FRESH }]
    end

    new(settings)
  end

  delegate :empty?, to: :to_h

  def run?(definition_id)
    settings_for(definition_id)[RUN] == true
  end

  def definition_ids_to_run
    @settings.select { |_id, settings| settings[RUN] == true }.keys
  end

  def input_for(definition_id)
    BlockInput.parse(settings_for(definition_id)[INPUT])
  end

  def to_h
    @settings
  end

  private

  def settings_for(definition_id)
    @settings.fetch(definition_id.to_s, { RUN => false, INPUT => BlockInput::FRESH })
  end

  # Params arrive as strings ('1'/'0' for the checkbox, and an unvalidated input
  # string). Coercing here means the rest of the app - and anything reading the
  # column back out of YAML - only ever sees booleans and canonical input strings.
  def normalize(settings)
    (settings || {}).to_h.each_with_object({}) do |(definition_id, block), normalized|
      block = block.to_h.with_indifferent_access

      normalized[definition_id.to_s] = {
        RUN => ActiveModel::Type::Boolean.new.cast(block[RUN]) || false,
        INPUT => BlockInput.parse(block[INPUT]).to_s
      }
    end
  end
end
