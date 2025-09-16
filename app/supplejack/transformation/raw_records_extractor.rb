# frozen_string_literal: true

module Transformation
  # This class extracts records from an extraction_job using the
  # transformation_definition record_selector
  class RawRecordsExtractor
    MAX_DOCUMENT_SIZE = 10.megabytes
    SUPPORTED_FORMATS = %w[json xml html].freeze

    def initialize(transformation_definition, extraction_job)
      @transformation_definition = transformation_definition
      @extraction_job = extraction_job
      @documents = extraction_job.documents
      @format = compute_format
      @record_selector = record_selector
    end

    # Returns the records from a specific request
    #
    # @return Array
    def records(page_number)
      page = page_number.to_i
      document = @documents[page]
      return [] unless document
      return [] if document.size_in_bytes > MAX_DOCUMENT_SIZE

      extractor = EXTRACTORS[@format]
      return [] unless extractor

      extractor.call(document.body, @record_selector)
    rescue Nokogiri::XML::XPath::SyntaxError
      []
    end

    private

    EXTRACTORS = {
      'html' => lambda { |body, selector|
        Nokogiri::HTML(body).xpath(selector).map(&:to_xml)
      },
      'xml' => lambda { |body, selector|
        Nokogiri::XML(body).xpath(selector).map(&:to_xml)
      },
      'json' => lambda { |body, selector|
        JsonPath.new(selector).on(body).flatten
      }
    }.freeze

    def compute_format
      format = @extraction_job.extraction_definition.format
      format == 'ARCHIVE_JSON' ? 'json' : format.downcase
    end

    def record_selector
      return @transformation_definition.record_selector if @transformation_definition.record_selector.present?

      @format == 'json' ? '*' : '/'
    end
  end
end
