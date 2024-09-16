# frozen_string_literal: true

# Wrapper interface for the HTTP Client used in Supplejack
# Intended on making transitioning to different HTTP Clients easier in the future
# As the client itself is abstracted away from our HTTP calls
#
module Extraction
  class Connection
    include HttpClient

    attr_reader :url, :params, :headers

    def initialize(url:, params: {}, headers: {}, method: 'get')
      headers ||= {}
      @connection = connection(url, params, headers)

      if method == 'get'
        @url = @connection.build_url
      else
        @url = url
      end
      
      @params     = @connection.params
      @headers    = @connection.headers
    end

    def get
      Response.new(@connection.get)
    end

    def post
      Response.new(connection(url, {}, headers).post(url, normalized_params.to_json, headers))
    end

    private

    # We store all values in the database as a string
    # but for POST requests the type can be important to the content source
    # so we need to convert string Integers into Integers
    def normalized_params
      params.transform_values do |value|
        if Integer(value, exception: false)
          Integer(value)
        else
          value
        end
      end
    end
  end
end
