# frozen_string_literal: true

module Api
  class Request
    def initialize(destination)
      @connection = Faraday.new(url: destination.url, headers: headers(destination.api_key)) do |builder|
        builder.request :json
        builder.response :json
      end
    end

    def get(path, params)
      @connection.get(path, params)
    end

    def post(path, params)
      @connection.post(path, params)
    end

    def put(path, params)
      @connection.put(path, params)
    end

    def delete(path)
      @connection.delete(path)
    end

    private

    def headers(api_key)
      {
        'Authentication-Token' => api_key,
        'Content-Type' => 'application/json'
      }
    end
  end
end
