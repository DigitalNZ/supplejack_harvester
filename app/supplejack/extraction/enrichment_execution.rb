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
        EnrichmentExtractionWorker.perform_async

        page = page_from_index(index)

        ee = new_enrichment_extraction(api_record, page)
        next unless ee.valid?

        ee.extract_and_save
        enqueue_record_transformation(api_record, ee.document, page)

        update_harvest_report

        throttle
        break if @extraction_job.reload.cancelled?
      end
    end

    def update_harvest_report
      return if @harvest_report.blank?

      @harvest_report.increment_pages_extracted!
      @harvest_report.update(extraction_updated_time: Time.zone.now)
    end

    def throttle
      sleep @extraction_definition.throttle / 1000.0
    end

    def page_from_index(index)
      ((@extraction_definition.page - 1) * @extraction_definition.per_page) + (index + 1)
    end

    def new_enrichment_extraction(api_record, page)
      EnrichmentExtraction.new(@extraction_definition.requests.last, ApiRecord.new(api_record), page,
                               @extraction_job.extraction_folder)
    end

    def enqueue_record_transformation(api_record, document, page)
      return unless @harvest_job.present? && document.successful?
      return if @extraction_definition.extract_text_from_file?

      TransformationWorker.perform_async(@harvest_job.id, page, api_record['id'])
      @harvest_report.increment_transformation_workers_queued! if @harvest_report.present?
    end
  end
end
