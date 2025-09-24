# frozen_string_literal: true

module Extraction
  class DefaultConnection < BaseConnection
    include DefaultHttpClient
  end
end
