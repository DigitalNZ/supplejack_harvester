# frozen_string_literal: true

module Load
  # A load the destination will refuse however many times it is asked: a batch it cannot
  # parse, a payload it will not accept, a definition with no business loading at all. Kept
  # apart from a transient refusal so that neither Retriable nor LoadWorker's requeue spends
  # twenty minutes on a batch that was never going to land.
  class PermanentError < StandardError; end
end
