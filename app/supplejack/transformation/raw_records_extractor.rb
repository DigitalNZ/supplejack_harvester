# frozen_string_literal: true

module Transformation
  # This class extracts records from an extraction_job using the
  # transformation_definition record_selector
  class RawRecordsExtractor
    # Pages larger than this are skipped to avoid exhausting worker memory while
    # parsing. It is deliberately high: a silently dropped page loses real data,
    # so this should only ever catch pathological responses, not ordinary large
    # ones (e.g. an OAI page containing a single very large record).
    MAX_PARSEABLE_PAGE_SIZE = 100.megabytes

    def initialize(transformation_definition, extraction_job)
      @transformation_definition = transformation_definition
      @extraction_job = extraction_job
      @documents = @extraction_job.documents
    end

    # Returns the records from a specific request
    #
    # @return Array
    def records(page_number)
      document = @documents[page_number.to_i]
      # blank? also catches the {} that Document.load_from_file returns for a
      # page file that is not JSON, e.g. a binary body (PDF, archive) saved raw.
      # Under an ARCHIVE_JSON definition such a page is a tar saved as-is by the
      # after-preprocess path, so its records are unpacked here instead.
      return archive_records(page_number) if document.blank?
      return [] if too_large_to_parse?(document, page_number)

      begin
        send(:"#{format.downcase}_extract", page_number)
      rescue NoMethodError, Nokogiri::XML::XPath::SyntaxError, JSON::ParserError, MultiJson::ParseError
        []
      end
    end

    private

    def too_large_to_parse?(document, page_number)
      return false if document.size_in_bytes <= MAX_PARSEABLE_PAGE_SIZE

      Rails.logger.warn(
        "RawRecordsExtractor: page #{page_number} (#{document.size_in_bytes} bytes) " \
        "exceeds the maximum parseable size of #{MAX_PARSEABLE_PAGE_SIZE} bytes and was skipped"
      )
      true
    end

    def html_extract(page)
      Nokogiri::HTML(@documents[page].body).xpath(record_selector).map(&:to_xml)
    end

    def xml_extract(page)
      Nokogiri::XML(@documents[page].body).xpath(record_selector).map(&:to_xml)
    end

    def json_extract(page)
      JsonPath.new(record_selector).on(@documents[page].body).flatten
    end

    def archive_records(page)
      return [] unless @extraction_job.extraction_definition.format == 'ARCHIVE_JSON'

      file_path = @documents.file_path_for(page)
      return [] if file_path.blank? || File.size(file_path) > MAX_PARSEABLE_PAGE_SIZE

      Extraction::Archive.entry_bodies_from_file(file_path).flat_map do |body|
        JsonPath.new(record_selector).on(body).flatten
      end
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
