# frozen_string_literal: true

module Api
  class Request
    def initialize(destination)
      @connection = Faraday.new(url: destination.url, headers: headers(destination.api_key)) do |builder|
        builder.request :json
        builder.response :json
      end
    end

    delegate :get, to: :@connection

    delegate :post, to: :@connection

    delegate :put, to: :@connection

    delegate :delete, to: :@connection

    private

    def headers(api_key)
      {
        'Authentication-Token' => api_key,
        'Content-Type' => 'application/json'
      }
    end
  end
end
