# frozen_string_literal: true

# Wrapper interface for the HTTP Client used in Supplejack
# Intended on making transitioning to different HTTP Clients easier in the future
# As the client itself is abstracted away from our HTTP calls
#
module Extraction
  class BaseConnection
    include HttpClient

    # The verbs that carry the request's parameters as a JSON body, rather than in the
    # query string. This is the line Faraday draws too (METHODS_WITH_BODY): a DELETE
    # takes a query, so it is built like a GET.
    PAYLOAD_METHODS = %w[post put patch].freeze

    attr_reader :url, :params, :headers

    def initialize(url:, params: {}, headers: {}, method: 'get')
      headers ||= {}
      @connection = build_connection(url, params, headers)
      @url = url_sent_with(method, url)
      @params = @connection.params
      @headers = @connection.headers
    end

    def get
      Response.new(@connection.get)
    end

    def delete
      Response.new(@connection.delete)
    end

    def post
      Response.new(payload_request(:post))
    end

    def put
      Response.new(payload_request(:put))
    end

    def patch
      Response.new(payload_request(:patch))
    end

    private

    # Builds the Faraday connection. Subclasses override this to change the
    # middleware stack (e.g. to disable following redirects).
    def build_connection(url, params, headers)
      connection(url, params, headers)
    end

    # A request carrying a payload is sent to the URL it was given: its parameters travel
    # in the body, so the query string built from them is not part of the URL.
    def url_sent_with(http_method, url)
      return url if PAYLOAD_METHODS.include?(http_method)

      @connection.build_url
    end

    # A request with a payload does not use @connection to avoid sending the URL params
    # as part of the URL which causes the URL to be too big and rejected by Webservers.
    def payload_request(http_method)
      build_connection(url, {}, headers).public_send(http_method, url, normalized_params.to_json, headers)
    end

    # We store all values in the database as a string
    # but for requests carrying a payload the type can be important to the content source
    # so we need to convert string Integers into Integers
    def normalized_params
      params.transform_values do |value|
        Integer(value, exception: false) || value
      end
    end
  end
end
