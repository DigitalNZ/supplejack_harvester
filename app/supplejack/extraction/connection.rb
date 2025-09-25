# frozen_string_literal: true

module Extraction
  class Connection < BaseConnection
    include HttpClient
  end
end
