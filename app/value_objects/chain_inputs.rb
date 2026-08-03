# frozen_string_literal: true

# Checks that a run's chain of blocks makes sense.
#
# A run starts at one block and continues to the end of the chain: it can skip the
# leading blocks (reusing data prepared earlier instead) but cannot leave a hole in
# the middle, because a block only exists to feed the one after it.
#
# The block it starts at needs something to read. Normally that is the previous
# block's feed-forward output, but when the run does not include the previous block
# the data has to come from somewhere the user nominated, or the run would extract
# from an empty folder and silently harvest nothing.
class ChainInputs
  def initialize(pipeline:, settings:)
    @pipeline = pipeline
    @settings = settings
  end

  def errors
    return [] if first_running.blank?

    [gap_error, input_error].compact
  end

  private

  def chain
    @chain ||= @pipeline.ordered_blocks.to_a
  end

  def first_running
    @first_running ||= chain.find { |definition| running?(definition) }
  end

  def running?(definition)
    @settings.run?(definition.id)
  end

  def gap_error
    skipped = chain.drop(chain.index(first_running)).reject { |definition| running?(definition) }
    return if skipped.empty?

    "#{skipped.map(&:source_id).to_sentence} must run too - a run continues to the end of the pipeline " \
      "once it starts at #{first_running.source_id}"
  end

  # Only the first running block can be short of an input: every later block is fed
  # by the one before it, which the no-gaps rule guarantees is running.
  def input_error
    return if preceding.blank?

    input = @settings.input_for(first_running.id)
    return if input.extraction_job? || usable_output?(input)

    input.preprocess_output? ? stale_output_error : missing_input_error
  end

  # The block before the one the run starts at, or nil when it starts at the top of
  # the chain and needs nothing supplied.
  def preceding
    return if chain.first == first_running

    chain[chain.index(first_running) - 1]
  end

  # 'latest' is resolved when the run starts, so there is nothing to check now.
  def usable_output?(input)
    return false unless input.preprocess_output?
    return true if input.latest?

    PreProcess::Output.pipeline_job_ids_with_output(preceding.position).include?(input.pipeline_job_id)
  end

  def missing_input_error
    "#{first_running.source_id} needs an input because #{preceding.source_id} is not running"
  end

  def stale_output_error
    "the run chosen for #{first_running.source_id} has no pre-processed data"
  end
end
