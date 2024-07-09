# frozen_string_literal: true

module Transformation
  # This class extracts records from an extraction_job using the
  # transformation_definition record_selector
  class RawRecordsExtractor
    def initialize(transformation_definition, extraction_job)
      @transformation_definition = transformation_definition
      @extraction_job = extraction_job
      @documents = @extraction_job.documents
    end

    # Returns the records from a specific request
    #
    # @return Array
    def records(page_number)
      return [] if @documents[page_number.to_i].nil?
      return [] if @documents[page_number.to_i].size_in_bytes > 10.megabytes

      begin
        send(:"#{format.downcase}_extract", page_number)
      rescue NoMethodError, Nokogiri::XML::XPath::SyntaxError
        []
      end
    end

    private

    def html_extract(page)
      Nokogiri::HTML(@documents[page].body).xpath(record_selector).map(&:to_xml)
    end

    def xml_extract(page)
      Nokogiri::XML(@documents[page].body).xpath(record_selector).map(&:to_xml)
    end

    def json_extract(page)
      JsonPath.new(record_selector).on(@documents[page].body).flatten
    end

    def format
      return 'JSON' if @extraction_job.extraction_definition.format == 'ARCHIVE_JSON'

      @extraction_job.extraction_definition.format
    end

    def record_selector
      return @transformation_definition.record_selector if @transformation_definition.record_selector.present?
      return '*' if format.in?(%w[JSON ARCHIVE_JSON])

      '/'
    end
  end
end
