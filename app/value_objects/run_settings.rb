# frozen_string_literal: true

# Per-block run configuration for a PipelineJob or a Schedule: for every block of
# the pipeline, whether it runs, where it takes its input from, and how many pages
# of it to process.
#
# Stored shape (block_settings), keyed by harvest_definition id as a string:
#
#   { '12' => { 'run' => true, 'input' => 'fresh', 'pages' => nil },
#     '13' => { 'run' => false, 'input' => 'fresh', 'pages' => nil },
#     '14' => { 'run' => true, 'input' => 'preprocess_output:44', 'pages' => 5 } }
#
# A nil page limit means every available page, which is what an unfilled field on the
# form means too.
#
# Runs created before this existed (and the API/automation paths, which still post
# the flat fields) have no block_settings, so #legacy builds an equivalent view from
# them. Every reader goes through this object, so there is one place that understands
# both shapes.
class RunSettings
  RUN = 'run'
  INPUT = 'input'
  PAGES = 'pages'

  # @param settings [Hash] the raw block_settings hash
  def initialize(settings = {})
    normalize(settings)
  end

  # The old flat fields expressed as per-block settings. extraction_job_id was a
  # single field applied to every non-enrichment block, which is exactly what this
  # reproduces - see HarvestWorker#child_perform before this change. The job-wide page
  # limit is handled by RunConfiguration#pages_for, because it applied to every block
  # whether or not it was listed as one to run.
  #
  # Keyword arguments rather than a options hash: a caller that gets a name wrong
  # should fail loudly instead of quietly producing an empty configuration.
  def self.legacy(definition_ids:, chain_ids: [], extraction_job_id: nil)
    chain = chain_ids.to_a.map(&:to_s)
    input = legacy_input(extraction_job_id)

    settings = definition_ids.to_a.compact_blank.index_with do |id|
      { RUN => true, INPUT => chain.include?(id.to_s) ? input : BlockInput::FRESH }
    end

    new(settings)
  end

  def self.legacy_input(extraction_job_id)
    return BlockInput::FRESH if extraction_job_id.blank?

    "#{BlockInput::EXTRACTION_JOB}:#{extraction_job_id}"
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

  # How many pages of this block to process, or nil for every available page.
  def pages_for(definition_id)
    settings_for(definition_id)[PAGES]
  end

  def to_h
    @settings
  end

  private

  def settings_for(definition_id)
    @settings.fetch(definition_id.to_s, { RUN => false, INPUT => BlockInput::FRESH, PAGES => nil })
  end

  # Params arrive as strings ('1'/'0' for the checkbox, and an unvalidated input
  # string). Coercing here means the rest of the app - and anything reading the
  # column back out of YAML - only ever sees booleans and canonical input strings.
  # nil.to_h is {}, which covers a record whose column has never been written.
  def normalize(settings)
    @settings = settings.to_h.to_h { |definition_id, block| [definition_id.to_s, normalized_block(block)] }
  end

  def normalized_block(block)
    values = block.to_h.with_indifferent_access

    {
      RUN => ActiveModel::Type::Boolean.new.cast(values[RUN]) || false,
      INPUT => BlockInput.parse(values[INPUT]).to_s,
      PAGES => page_limit(values[PAGES])
    }
  end

  # An empty field, a zero or anything unparseable all mean "every page", which is
  # the safe reading: process what is there rather than silently stopping early.
  def page_limit(value)
    limit = value.to_i
    limit.positive? ? limit : nil
  end
end
