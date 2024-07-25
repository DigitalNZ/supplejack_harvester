# frozen_string_literal: true

Retriable.configure do |c|
  c.tries = 10
  c.base_interval = 3
  c.multiplier = 2
end
