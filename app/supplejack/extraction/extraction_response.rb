# frozen_string_literal: true

module Extraction
  class ExtractionResponse
    attr_reader :body, :headers

    def initialize(response_object)
      @body = response_object.body
      @headers = response_object.response_headers
    end

    delegate :[], to: :body
  end
end
