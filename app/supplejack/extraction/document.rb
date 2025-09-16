# frozen_string_literal: true

require 'fileutils'
require 'oj'

module Extraction
  class Document
    attr_reader :status, :request_headers, :response_headers, :url, :method, :params, :file_path
    attr_accessor :body

    Oj.default_options = { mode: :compat }

    # rubocop:disable Metrics/ParameterLists
    def initialize(file_path = nil, url: nil, method: nil, params: nil, request_headers: nil, status: nil,
                   response_headers: nil, body: nil)
      @file_path = file_path
      @url = url
      @method = method
      @params = params
      @request_headers = request_headers
      @status = status
      @response_headers = response_headers
      @body = body
    end
    # rubocop:enable Metrics/ParameterLists

    def successful?
      status.to_i >= 200 && status.to_i < 300
    end

    def save(file_path)
      FileUtils.mkdir_p(File.dirname(file_path))

      begin
        json_data = to_json
        File.write(file_path, json_data)
      rescue Oj::Error, Encoding::UndefinedConversionError => e
        Rails.logger.warn { "Failed to serialize Document to JSON (#{e.class}): #{e.message}. Saving body as binary." }
        File.write(file_path, body.to_s, mode: 'wb')
      end
    end

    def size_in_bytes
      return 0 unless file_path && File.exist?(file_path)

      File.size(file_path)
    end

    def self.load_from_file(file_path)
      Rails.logger.debug { "Loading document #{file_path}" }

      File.open(file_path, 'r') do |f|
        json = Oj.load(f, symbol_keys: true)
        new(file_path, **json)
      end
    rescue Oj::ParseError => e
      Rails.logger.error { "Failed to parse JSON from #{file_path}: #{e.message}" }
      nil
    end

    def to_hash
      {
        url: url,
        method: method,
        params: params,
        request_headers: request_headers,
        status: status,
        response_headers: response_headers,
        body: body
      }
    end

    def to_json(*)
      @to_json ||= Oj.dump(to_hash, mode: :compat)
    end
  end
end
