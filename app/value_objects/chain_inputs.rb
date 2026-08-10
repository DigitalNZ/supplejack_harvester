# frozen_string_literal: true

# Checks that a run's chain of blocks makes sense.
#
# A run covers one unbroken stretch of the chain. It can start late, reusing data
# prepared earlier instead of running the blocks before it, and it can stop early -
# pre-processing now and harvesting later is a legitimate thing to want. What it cannot
# do is leave a hole in the middle: a block only exists to feed the one after it, so
# skipping one and running the next means the next has nothing to read.
#
# The block it starts at needs something to read too. Normally that is the previous
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

  # Blocks the run skips over on its way to a later one it does run. Blocks before the
  # first and after the last are simply not part of this run, which is allowed.
  def gap_error
    skipped = running_stretch.reject { |definition| running?(definition) }
    return if skipped.empty?

    "#{skipped.map(&:source_id).to_sentence} must run too - a run cannot skip a block and " \
      'then run a later one, which would have nothing to read'
  end

  def running_stretch
    chain[chain.index(first_running)..chain.index(last_running)]
  end

  def last_running
    @last_running ||= chain.reverse.find { |definition| running?(definition) }
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
