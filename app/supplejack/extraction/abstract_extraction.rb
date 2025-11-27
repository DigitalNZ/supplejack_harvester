# frozen_string_literal: true

module Extraction
  class AbstractExtraction
    attr_accessor :document

    def extract
      ::Retriable.retriable do
        @document = Extraction::Request.new(url:, params:, headers:, method: http_method).send(http_method)
      end
    rescue StandardError => e
      logger.info "Extraction error: #{e}"
    end

    def save
      raise ArgumentError, 'extraction_folder was not provided in #new' if @extraction_folder.blank?
      raise '#extract must be called before #save AbstractExtraction' if @document.blank?

      @document.save(file_path)
    end

    def extract_and_save
      extract
      save
    end

    private

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
