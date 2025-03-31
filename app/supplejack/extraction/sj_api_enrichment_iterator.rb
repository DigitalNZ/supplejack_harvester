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

    def each
      yield(@first_api_document, @page)
      @page += 1

      (@page..@max_page).each do |page|
        break if @extraction_job.reload.cancelled?

        yield(get_api_document(page), page)
      end
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
