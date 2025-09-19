# frozen_string_literal: true

module HttpClient
  extend ActiveSupport::Concern

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Style/OptionalBooleanParameter
  def connection(url, params, headers, follow_redirects = true)
    if follow_redirects
      Faraday.new(url:, params:, headers:) do |f|
        f.response :follow_redirects, limit: 5
        f.adapter Faraday.default_adapter
      end
    else
      Faraday.new(url:, params:, headers:) do |f|
        f.response :logger
        f.adapter Faraday.default_adapter
      end
    end
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Style/OptionalBooleanParameter
end
