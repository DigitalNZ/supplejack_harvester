# frozen_string_literal: true

class EnrichmentExtractionWorker
  include PerformWithPriority
  include Sidekiq::Job
  include Extraction::Concerns::EnrichmentExtractionProcess

  def perform(enrichment_params)
    process_enrichment_extraction(enrichment_params)
  rescue StandardError => e
    log_enrichment_extraction_error(e, enrichment_params)
    raise
  end

  private

  def log_enrichment_extraction_error(exception, enrichment_params)
    params = JSON.parse(enrichment_params)
    extraction_definition = ExtractionDefinition.find(params['extraction_definition_id'])

    return unless extraction_definition&.harvest_definition&.source_id

    JobCompletionSummary.log_error(
      extraction_id: extraction_definition.harvest_definition.source_id,
      extraction_name: extraction_definition.harvest_definition.name,
      message: "EnrichmentExtractionWorker error: #{exception.class} - #{exception.message}",
      details: {
        worker_class: self.class.name,
        exception_class: exception.class.name,
        exception_message: exception.message,
        stack_trace: exception.backtrace&.first(20),
        extraction_job_id: params['extraction_job_id'],
        extraction_definition_id: params['extraction_definition_id'],
        harvest_job_id: params['harvest_job_id'],
        api_record: params['api_record'],
        page: params['page'],
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log enrichment extraction error to JobCompletionSummary: #{e.message}"
  end
end
