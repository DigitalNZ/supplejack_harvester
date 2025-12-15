# frozen_string_literal: true

module Extraction
  # Iterates over documents from a previous extraction job,
  # treating each document as a "record" for chained extraction processing.
  class DocumentIterator
    def initialize(source_extraction_job)
      @source_job = source_extraction_job
    end

    def each
      return enum_for(:each) unless block_given?
      return if @source_job.blank?

      documents = @source_job.documents

      (1..documents.total_pages).each do |page_number|
        doc = documents[page_number]
        next if doc.blank? || doc.body.blank?

        # Parse the document body as the "record" data
        record_data = parse_document(doc)
        yield record_data, page_number
      end
    end

    private

    def parse_document(doc)
      # Try to parse as JSON first
      JSON.parse(doc.body)
    rescue JSON::ParserError
      # For HTML/XML, wrap the body in a hash so dynamic params can access it
      { 'body' => doc.body }
    end
  end
end
