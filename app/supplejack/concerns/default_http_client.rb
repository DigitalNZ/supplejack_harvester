# frozen_string_literal: true

module DefaultHttpClient
  extend ActiveSupport::Concern

  def connection(url, params, headers)
    Faraday.new(url:, params:, headers:) do |f|
      f.response :logger
      f.adapter Faraday.default_adapter
    end
  end
end
