# frozen_string_literal: true

class EnrichmentExtractionWorker
  include PerformWithPriority
  include Sidekiq::Job
  include Extraction::Concerns::EnrichmentExtractionProcess

  def perform(enrichment_params)
    process_enrichment_extraction(enrichment_params)
  rescue StandardError => e
    extraction_info = Supplejack::JobCompletionSummaryLogger.extract_from_enrichment_params(enrichment_params)
    return unless extraction_info

    params = JSON.parse(enrichment_params)
    Supplejack::JobCompletionSummaryLogger.log_completion(
      worker_class: 'EnrichmentExtractionWorker',
      exception: e,
      extraction_id: extraction_info[:extraction_id],
      extraction_name: extraction_info[:extraction_name],
      details: {
        extraction_job_id: params['extraction_job_id'],
        extraction_definition_id: params['extraction_definition_id'],
        harvest_job_id: params['harvest_job_id'],
        api_record: params['api_record'],
        page: params['page']
      }
    )
    raise
  end
end
