# frozen_string_literal: true

# Checks that every block a run will run has something to read.
#
# A block at position > 0 normally eats the previous block's feed-forward output. If
# that previous block is not part of the run, the data has to come from somewhere the
# user nominated, or the run would extract from an empty folder and silently harvest
# nothing.
class ChainInputs
  def initialize(pipeline:, settings:)
    @pipeline = pipeline
    @settings = settings
  end

  # One message per block that will run without a usable input.
  def errors
    @pipeline.ordered_blocks.each_cons(2).filter_map do |preceding, definition|
      next unless needs_supplied_input?(preceding, definition)

      error_for(preceding, definition)
    end
  end

  private

  def needs_supplied_input?(preceding, definition)
    @settings.run?(definition.id) && !@settings.run?(preceding.id)
  end

  def error_for(preceding, definition)
    input = @settings.input_for(definition.id)
    return if input.extraction_job?
    return missing_input(preceding, definition) unless input.preprocess_output?
    return if usable_output?(input, preceding)

    "the run chosen for #{definition.source_id} has no pre-processed data"
  end

  def missing_input(preceding, definition)
    "#{definition.source_id} needs an input because #{preceding.source_id} is not running"
  end

  # 'latest' is resolved when the run starts, so there is nothing to check now.
  def usable_output?(input, preceding)
    return true if input.latest?

    PreProcess::Output.pipeline_job_ids_with_output(preceding.position).include?(input.pipeline_job_id)
  end
end
