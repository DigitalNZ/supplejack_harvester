# frozen_string_literal: true

module HttpClient
  extend ActiveSupport::Concern

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
end
