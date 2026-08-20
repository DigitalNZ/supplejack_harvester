# frozen_string_literal: true

module Extraction
  # Makes the actual request
  # Stores the request and response details
  class Request
    def initialize(url:, params: {}, headers: {}, method: 'get', follow_redirects: true)
      @connection = if follow_redirects
                      Connection.new(url:, params:, headers:, method:)
                    else
                      ConnectionWithoutRedirects.new(url:, params:, headers:, method:)
                    end
    end

    # Returns a document based on the given request
    #
    # @return Document object
    def get
      perform('GET')
    end

    def post
      perform('POST')
    end

    def put
      perform('PUT')
    end

    def patch
      perform('PATCH')
    end

    def delete
      perform('DELETE')
    end

    private

    # AbstractExtraction picks the method to call from the request's http_method, so
    # every verb the Request model knows about has to answer to its own name here.
    def perform(http_method)
      @response = @connection.public_send(http_method.downcase)
      document(http_method)
    end

    def document(http_method)
      Document.new(
        url: @connection.url,
        method: http_method,
        params: @connection.params,
        request_headers: @connection.headers,
        status: @response.status,
        response_headers: @response.headers,
        body: @response.body
      )
    end
  end
end
