# frozen_string_literal: true

module Api
  class ApplicationController < ActionController::Base
    skip_before_action :verify_authenticity_token
    before_action :authenticate_api_key

    private

    def authenticate_api_key
      authenticate_or_request_with_http_token do |token, _options|
        User.find_by(api_key: token).admin?
      end
    end
  end
end
