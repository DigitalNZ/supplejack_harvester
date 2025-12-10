# frozen_string_literal: true

module HttpClient
  extend ActiveSupport::Concern

  def connection(url, params, headers)
    Faraday.new(url:, params:, headers:) do |faraday|
      faraday.response :follow_redirects, limit: 5
      faraday.adapter Faraday.default_adapter
    end
  end

  def connection_follow_no_redirects(url, params, headers)
    Faraday.new(url:, params:, headers:) do |faraday|
      faraday.adapter Faraday.default_adapter
    end
  end
end
