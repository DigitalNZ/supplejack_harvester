# frozen_string_literal: true

module Extraction
  # Manages the filesystem part of the request object
  # Saves it to filesystem and loads it in memory
  class Document
    attr_reader :status, :request_headers, :response_headers, :body, :url, :method, :params, :file_path

    def initialize(file_path = nil, **kwargs)
      @file_path = file_path
      @url = kwargs[:url]
      @method = kwargs[:method]
      @params = kwargs[:params]
      @request_headers = kwargs[:request_headers]
      @status = kwargs[:status]
      @response_headers = kwargs[:response_headers]
      @body = kwargs[:body]
    end

    def successful?
      status >= 200 && status < 300
    end

    def save(file_path)
      if @response_headers.present? && @response_headers['content-type'] == 'application/pdf'
        File.write(file_path, @body, mode: 'wb')
      else
        File.write(file_path, to_json)
      end
    end

    def size_in_bytes
      return if file_path.nil?

      File.size(file_path)
    end

    def self.load_from_file(file_path)
      Rails.logger.debug { "Loading document #{file_path}" }
      json = JSON.parse(File.read(file_path)).symbolize_keys
      Document.new(file_path, **json)
    end

    def to_hash
      {
        url:,
        method:,
        params:,
        request_headers:,
        status:,
        response_headers:,
        body:
      }
    end

    def to_json(*args)
      JSON.generate(to_hash, *args)
    end
  end
end
