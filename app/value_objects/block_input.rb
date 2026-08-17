# frozen_string_literal: true

# Where a single block of the processing chain gets its input from.
#
# Serialised as a short string so it can live in a form select's value and in the
# block_settings hash without a nested structure:
#
#   'fresh'                    the block does whatever it normally does - a seed
#                              extraction at position 0, the previous block's
#                              feed-forward output at position > 0
#   'extraction_job:987'       skip extraction, transform the documents already
#                              on disk for ExtractionJob 987
#   'preprocess_output:44'     iterate the pre-processed records that PipelineJob
#                              44 wrote for the preceding position
#   'preprocess_output:latest' same, but resolved at run time to the most recent
#                              run with output for that position (for schedules,
#                              where a pinned id goes stale)
class BlockInput
  FRESH = 'fresh'
  EXTRACTION_JOB = 'extraction_job'
  PREPROCESS_OUTPUT = 'preprocess_output'
  LATEST = 'latest'

  KINDS = [FRESH, EXTRACTION_JOB, PREPROCESS_OUTPUT].freeze

  attr_reader :kind, :reference

  # Anything unrecognised falls back to 'fresh' rather than raising: this value
  # comes from user-submitted params, and the safe reading of a malformed input
  # is "run the block the normal way".
  def self.parse(value)
    kind, reference = value.to_s.split(':', 2)
    return new(FRESH) unless kind.in?(KINDS)
    return new(FRESH) if kind != FRESH && reference.blank?

    new(kind, reference)
  end

  def initialize(kind, reference = nil)
    @kind = kind
    @reference = reference
  end

  def fresh?
    kind == FRESH
  end

  def extraction_job?
    kind == EXTRACTION_JOB
  end

  def preprocess_output?
    kind == PREPROCESS_OUTPUT
  end

  def latest?
    reference == LATEST
  end

  def extraction_job_id
    reference.to_i if extraction_job?
  end

  # nil for 'latest' - the caller resolves that against the pipeline, because it
  # needs to know which position's output it is looking for.
  def pipeline_job_id
    return if !preprocess_output? || latest?

    reference.to_i
  end

  def to_s
    fresh? ? FRESH : "#{kind}:#{reference}"
  end
end
