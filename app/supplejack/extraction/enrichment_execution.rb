# frozen_string_literal: true

module Extraction
  class EnrichmentExecution
    def initialize(extraction_job)
      @extraction_job = extraction_job
      @extraction_definition = extraction_job.extraction_definition
      @harvest_job = extraction_job.harvest_job
      @harvest_report = @harvest_job.harvest_report if @harvest_job.present?
    end

    def call
      SjApiEnrichmentIterator.new(@extraction_job).each do |api_document, page|
        @extraction_definition.page = page
        api_records = JSON.parse(api_document.body)['records']
        extract_and_save_enrichment_documents(api_records)
      end
    end

    private

    def extract_and_save_enrichment_documents(api_records)
      api_records.each_with_index do |api_record, index|
        page = page_from_index(index)
        
        # TODO: This should only perform async if the user has selected this option
        EnrichmentExtractionWorker.perform_async(@extraction_definition.id,
                                                 @extraction_job.id,
                                                 @harvest_job.id,
                                                 api_record,
                                                 page)

        break if @extraction_job.reload.cancelled?
      end
    end

    def throttle
      sleep @extraction_definition.throttle / 1000.0
    end

    def page_from_index(index)
      ((@extraction_definition.page - 1) * @extraction_definition.per_page) + (index + 1)
    end
  end
end
