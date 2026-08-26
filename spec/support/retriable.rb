# frozen_string_literal: true

require 'retriable'

Retriable.configure do |c|
  c.tries = 2
  # Don't spend the backoff for real, it is dead time in the suite
  c.base_interval = 0

  # Mirrors the shape of the :load context the initializer defines, without the waiting. The
  # context has to be redefined rather than left alone: neither setting above reaches into it,
  # so the load path would otherwise keep its production try count and its real backoff.
  c.contexts[:load] = { tries: 2, base_interval: 0, max_elapsed_time: nil }
end
