# frozen_string_literal: true

module Extraction
  class JavascriptRequest
    def initialize(url:, params:)
      @url = url
      @params = params
      @driver = driver
    end

    def get
      begin
        @driver.get(full_url)
        @document = document(200)
      rescue StandardError
        @document = document(500)
      ensure
        @driver.quit
      end

      @document
    end

    private

    def full_url
      return @url if @params.blank?

      "#{@url}?#{@params.to_query}"
    end

    def document(status)
      Document.new(
        url: full_url,
        method: 'GET',
        params: @params&.to_query || {},
        request_headers: [],
        status:,
        body: @driver.page_source || '',
        response_headers: []
      )
    end

    def driver
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--ignore-certificate-errors')
      options.add_argument('--disable-translate')
      options.add_argument('--no-sandbox')
      options.add_argument('--headless')
      options.add_argument('--disable-gpu')
      Selenium::WebDriver.for(:chrome, options:)
    end
  end
end
