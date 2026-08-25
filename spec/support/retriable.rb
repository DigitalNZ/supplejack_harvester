# frozen_string_literal: true

require 'retriable'

Retriable.configure do |c|
  c.tries = 2
  # Don't spend the backoff for real, it is dead time in the suite
  c.base_interval = 0
end
