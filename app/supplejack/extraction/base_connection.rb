# frozen_string_literal: true

# Wrapper interface for the HTTP Client used in Supplejack
# Intended on making transitioning to different HTTP Clients easier in the future
# As the client itself is abstracted away from our HTTP calls
#
module Extraction
  class BaseConnection
    include HttpClient

    attr_reader :url, :params, :headers

    def initialize(url:, params: {}, headers: {}, method: 'get')
      headers ||= {}
      @connection = connection(url, params, headers)
      @url = method == 'get' ? @connection.build_url : url
      @params = @connection.params
      @headers = @connection.headers
    end

    def get
      Response.new(@connection.get)
    end

    def post
      Response.new(post_request)
    end

    private

    # The POST request does not use @connection to avoid sending the URL params
    # as part of the URL which causes the URL to be too big and rejected by Webservers.
    def post_request
      connection(url, {}, headers).post(url, normalized_params.to_json, headers)
    end

    # We store all values in the database as a string
    # but for POST requests the type can be important to the content source
    # so we need to convert string Integers into Integers
    def normalized_params
      params.transform_values do |value|
        Integer(value, exception: false) || value
      end
    end
  end
end
