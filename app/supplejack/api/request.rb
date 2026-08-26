# frozen_string_literal: true

module Api
  class Request
    # The read timeout is left out altogether when there is nothing to say, rather than passed
    # as nil: Faraday merges this over config/initializers/faraday.rb's defaults, so an
    # explicit nil would clear the app-wide read timeout instead of falling back to it.
    def initialize(destination, read_timeout: nil)
      options = { url: destination.url, headers: headers(destination.api_key) }
      options[:request] = { timeout: read_timeout } if read_timeout.present?

      @connection = Faraday.new(**options) do |builder|
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
