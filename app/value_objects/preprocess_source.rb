# frozen_string_literal: true

# Where a single block's extraction gets its records when it is run on its own, outside a
# pipeline run.
#
# A block after the first in the chain has none of its own to start from: it works from
# the records an earlier run pre-processed. The pipeline page's dropdown names the run
# (see pipelines/_run_extraction_modal); the editor's "Run sample and transform data" has
# nowhere to ask, so it falls back to the most recent run holding output, which is the one
# being worked on.
#
# The position is recorded alongside the run because output folders are keyed by position
# on disk: reordering the blocks later must not re-point a job that has already run.
class PreprocessSource
  def initialize(pipeline:, harvest_definition:, nominated_run_id: nil)
    @pipeline = pipeline
    @harvest_definition = harvest_definition
    @nominated_run_id = nominated_run_id
  end

  # Whether this block reads records rather than seeding its own extraction.
  def required?
    @harvest_definition.consumes_preprocess_output?
  end

  # Nothing has been pre-processed for it to read. Extracting anyway would build every
  # request from an unevaluated parameter and fetch a meaningless URL.
  def missing?
    required? && run_id.blank?
  end

  def run_id
    @nominated_run_id.presence || latest_run_with_output&.id
  end

  # Merged into the extraction job's attributes; empty for a block that seeds itself.
  def attributes
    return {} unless required?

    { source_pipeline_job_id: run_id, source_position: @harvest_definition.preceding_position }
  end

  private

  def latest_run_with_output
    @pipeline.runs_with_output_at(@harvest_definition.preceding_position).first
  end
end
