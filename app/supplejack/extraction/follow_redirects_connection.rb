# frozen_string_literal: true

module Extraction
  class FollowRedirectsConnection < BaseConnection
    include FollowRedirectsHttpClient
  end
end
