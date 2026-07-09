# frozen_string_literal: true

module Extraction
  class SjApiEnrichmentIterator
    def initialize(extraction_job)
      @extraction_job = extraction_job
      @extraction_definition = extraction_job.extraction_definition
      @harvest_job = extraction_job.harvest_job

      @page = @extraction_definition.page
      @first_api_document = get_api_document(@page)
      @max_page = find_max_page(@first_api_document) if @first_api_document.body.present?
    end

    # Enriching a record removes it from the 'skip previously enriched'
    # filtered results, shifting every record behind it forward a page.
    # Pages are processed from last to first so that the shrinking result
    # set never shifts records into a page that has already been processed.
    def each
      if @max_page.present?
        @max_page.downto(@page + 1).each do |page|
          break if @extraction_job.reload.cancelled?

          yield(get_api_document(page), page)
        end
      end

      yield(@first_api_document, @page)
    end

    def find_max_page(record_extraction)
      return 1 if @extraction_job.is_sample?

      JsonPath.new(@extraction_definition.total_selector).on(record_extraction.body).first.to_i
    end

    def get_api_document(page)
      RecordExtraction.new(
        @extraction_definition.requests.first, page, @harvest_job
      ).extract
    end
  end
end
