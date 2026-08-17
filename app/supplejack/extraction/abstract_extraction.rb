# frozen_string_literal: true

module Extraction
  class AbstractExtraction
    attr_accessor :document
    attr_reader :extraction_error

    def extract
      ensure_requestable_url

      ::Retriable.retriable do
        @document = Extraction::Request.new(url:, params:, headers:, method: http_method).send(http_method)
      end
    rescue StandardError => e
      @extraction_error = e
      ::Rails.logger.info "Extraction error: #{e}" if defined?(Sidekiq)
    end

    # The URL the extraction tried, for reporting what failed. Never raises: it is only
    # ever asked for when something has already gone wrong.
    def attempted_url
      url
    rescue StandardError
      nil
    end

    def save
      raise ArgumentError, 'extraction_folder was not provided in #new' if @extraction_folder.blank?
      raise '#extract must be called before #save AbstractExtraction' if @document.blank?

      @document.save(file_path)
    end

    # Reports why the extraction produced nothing, rather than leaving #save to
    # complain that #extract was never called - which sends whoever reads the job
    # looking in the wrong place entirely.
    def extract_and_save
      extract

      raise "#{url} could not be extracted: #{extraction_error.message}" if extraction_error.present?

      save
    end

    private

    # A URL the request layer cannot parse will never become parseable, so raise
    # before Retriable spends its whole backoff on it. The usual cause is a request
    # parameter that was not evaluated - a dynamic expression left as a static
    # parameter, for instance - leaving its #{...} in the URL.
    def ensure_requestable_url
      URI.parse(url)
    rescue URI::Error => e
      raise e.class, "#{e.message} - check the request's parameters"
    end

    def url
      raise 'url not defined in child class'
    end

    def params
      raise 'params not defined in child class'
    end

    def file_path
      raise 'file_path not defined in child class'
    end

    def headers
      {
        'Content-Type' => 'application/json',
        'User-Agent' => 'Supplejack Harvester v2.0'
      }
    end

    def folder_number(page = 1)
      (page / Extraction::Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
    end

    def http_method
      return 'get' if @request.nil?

      @request.http_method.downcase
    end
  end
end
