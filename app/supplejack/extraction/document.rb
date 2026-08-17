# frozen_string_literal: true

module Extraction
  # Manages the filesystem part of the request object
  # Saves it to filesystem and loads it in memory
  class Document
    attr_reader :status, :request_headers, :response_headers, :url, :method, :params, :file_path
    attr_accessor :body

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

    # A stand-in for a page with no file behind it, handed out by Documents#[] so
    # callers always get an object back. There is nothing to show for one, and showing
    # it hides why the file is missing - the job may have failed, or not run yet.
    def missing?
      file_path.blank?
    end

    def save(file_path)
      # Create the directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(file_path))

      File.write(file_path, to_json)
      # If the file fails to be converted to a JSON document
      # write the original file to the filepath as a binary
      # It is probably a PDF or Word Doc
    rescue JSON::GeneratorError
      File.write(file_path, @body, mode: 'wb')
    end

    def size_in_bytes
      return 0 if file_path.nil?

      File.size(file_path)
    end

    def self.load_from_file(file_path)
      Rails.logger.debug { "Loading document #{file_path}" }
      json = JSON.parse(File.read(file_path)).symbolize_keys
      Document.new(file_path, **json)
    rescue JSON::ParserError
      {}
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

    def to_json(*)
      JSON.generate(to_hash, *)
    end
  end
end
