# frozen_string_literal: true

module Extraction
  class ExtractionResponse
    def initialize(response_object)
      @body = response_object.body
      @headers = response_object.response_headers
    end

    attr_reader :body, :headers
  end
end
