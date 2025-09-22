# frozen_string_literal: true

module Extraction
  class EnrichmentExecution
    include Extraction::Concerns::EnrichmentExtractionProcess

    def initialize(extraction_job)
      @extraction_job = extraction_job
      @extraction_definition = extraction_job.extraction_definition
      @harvest_job = extraction_job.harvest_job
      @harvest_report = @harvest_job.harvest_report if @harvest_job.present?
    end

    def call
      SjApiEnrichmentIterator.new(@extraction_job).each do |api_document, page|
        break if api_document.body.blank?

        @extraction_definition.page = page
        api_records = JSON.parse(api_document.body)['records']
        extract_and_save_enrichment_documents(api_records)
      end
    rescue StandardError => e
      log_enrichment_error(e)
      raise
    end

    private

    def extract_and_save_enrichment_documents(api_records)
      api_records.each_with_index do |api_record, index|
        enrichment_params = ExtractionParams.new(@extraction_definition.id,
                                                 @extraction_job.id,
                                                 @harvest_job&.id,
                                                 api_record,
                                                 page_from_index(index))
        process_enrichment(enrichment_params)

        break if extraction_cancelled?
      end
    end

    def extraction_cancelled?
      @extraction_job.reload.cancelled?
    end

    def process_enrichment(enrichment_params)
      json_params = enrichment_params.to_json
      if @harvest_job&.pipeline_job&.run_enrichment_concurrently?
        EnrichmentExtractionWorker.perform_async_with_priority(@harvest_job.pipeline_job.job_priority, json_params)
      else
        throttle
        process_enrichment_extraction(json_params)
      end
    end

    def throttle
      sleep @extraction_definition.throttle / 1000.0
    end

    def page_from_index(index)
      ((@extraction_definition.page - 1) * @extraction_definition.per_page) + (index + 1)
    end

    def log_enrichment_error(exception)
      return unless @extraction_definition&.harvest_definition&.source_id

      Supplejack::JobCompletionSummaryLogger.log_error(
        extraction_id: @extraction_definition.harvest_definition.source_id,
        extraction_name: @extraction_definition.harvest_definition.name,
        message: "Enrichment execution error: #{exception.class} - #{exception.message}",
        details: {
          worker_class: self.class.name,
          exception_class: exception.class.name,
          exception_message: exception.message,
          stack_trace: exception.backtrace&.first(20),
          extraction_job_id: @extraction_job.id,
          extraction_definition_id: @extraction_definition.id,
          harvest_job_id: @harvest_job&.id,
          harvest_report_id: @harvest_report&.id,
          timestamp: Time.current.iso8601
        }
      )
    rescue StandardError => e
      Rails.logger.error "Failed to log enrichment error to JobCompletionSummary: #{e.message}"
    end
  end
end
