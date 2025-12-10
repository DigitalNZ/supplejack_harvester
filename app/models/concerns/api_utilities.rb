# frozen_string_literal: true

# Shared utilities for API requests and variable interpolation
module ApiUtilities
  extend ActiveSupport::Concern

  private

  # HTTP request handling

  def setup_http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http
  end

  def request_class_for_method(method)
    request_classes = {
      'GET' => Net::HTTP::Get,
      'POST' => Net::HTTP::Post,
      'PUT' => Net::HTTP::Put,
      'PATCH' => Net::HTTP::Patch,
      'DELETE' => Net::HTTP::Delete
    }

    request_class = request_classes[method]
    raise "Unsupported HTTP method: #{method}" unless request_class

    request_class
  end

  def add_request_headers(request, headers_json)
    return if headers_json.blank?

    JSON.parse(headers_json).each do |key, value|
      request[key] = value
    end
  end

  # Variable interpolation

  def interpolate_variables(body)
    return body unless body.is_a?(String)

    # Try to parse as JSON first
    begin
      # Parse the body into a hash
      body_hash = JSON.parse(body)

      # Deep traverse the hash and replace any {{job_ids}} placeholders
      traverse_and_replace(body_hash)

      # Convert back to JSON
      body_hash.to_json
    rescue JSON::ParserError
      # If not valid JSON, fall back to string replacement
      job_ids = collect_pipeline_job_ids
      body.gsub('{{job_ids}}', job_ids.to_json)
    end
  end

  def traverse_and_replace(obj)
    case obj
    when Hash
      obj.each { |key, value| obj[key] = traverse_and_replace(value) }
    when Array
      obj.map! { |item| traverse_and_replace(item) }
    when String
      replace_placeholders(obj)
    else
      obj
    end
  end

  def replace_placeholders(text)
    if text.include?('{{job_ids}}')
      job_ids = collect_pipeline_job_ids
      text.gsub('{{job_ids}}', job_ids.to_json)
    else
      text
    end
  end
end
