# frozen_string_literal: true

Retriable.configure do |c|
  c.tries = ENV.fetch('RETRIABLE_TRIES', 10).to_i
  c.base_interval = ENV.fetch('RETRIABLE_BASE_INTERVAL', 2).to_i
  c.multiplier = ENV.fetch('RETRIABLE_MULTIPLIER', 2).to_i
end
