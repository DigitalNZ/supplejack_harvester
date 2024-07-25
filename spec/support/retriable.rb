# frozen_string_literal: true

require 'retriable'

Retriable.configure do |c|
  c.tries = 2
end
