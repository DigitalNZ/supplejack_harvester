# frozen_string_literal: true

# Wrapper around Request that overrides the URL to use a specific link URL
# Used for link extraction where each link needs its own URL
class LinkRequest
  def initialize(original_request, link_url)
    @original_request = original_request
    @link_url = link_url
  end

  def url(_response = nil)
    @link_url
  end

  def query_parameters(response = nil)
    @original_request.query_parameters(response)
  end

  def headers(response = nil)
    @original_request.headers(response)
  end

  def http_method
    @original_request.http_method
  end

  def extraction_definition
    @original_request.extraction_definition
  end

  # Delegate any other methods to the original request
  def method_missing(method, *args, &block)
    if @original_request.respond_to?(method)
      @original_request.public_send(method, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(method, include_private = false)
    @original_request.respond_to?(method, include_private) || super
  end
end

