# frozen_string_literal: true

module Extraction
  # Simple wrapper for Request that uses a specific URL from independent-extraction
  class IndependentExtractionRequest
    def initialize(base_request, url)
      @base_request = base_request
      @url = url
    end

    def url(_response = nil)
      @url
    end

    def query_parameters(response = nil)
      @base_request.query_parameters(response)
    end

    def headers(response = nil)
      @base_request.headers(response)
    end

    def extraction_definition
      @base_request.extraction_definition
    end

    def http_method
      @base_request.http_method
    end
  end
end


