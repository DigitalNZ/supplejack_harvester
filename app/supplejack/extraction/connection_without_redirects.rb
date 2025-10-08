# frozen_string_literal: true

module Extraction
  class ConnectionWithoutRedirects < BaseConnection
    private

    def build_connection(url, params, headers)
      connection_follow_no_redirects(url, params, headers)
    end
  end
end
