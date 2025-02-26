# frozen_string_literal: true

# This class is for normalizing data received from the API
# so that it can be treated the same as a response from our HTTP Client

module Extraction
  class ApiRecord
    attr_reader :body

    def initialize(body)
      @body = body
    end

    delegate :[], to: :@body

    def to_hash
      {
        body: body.to_json
      }
    end
  end
end
