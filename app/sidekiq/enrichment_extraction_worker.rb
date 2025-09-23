# frozen_string_literal: true

class EnrichmentExtractionWorker
  include PerformWithPriority
  include Sidekiq::Job
  include Extraction::Concerns::EnrichmentExtractionProcess

  def perform(enrichment_params)
    process_enrichment_extraction(enrichment_params)
  rescue StandardError => e
    params = JSON.parse(enrichment_params)
    extraction_definition_id = params['extraction_definition_id']
    extraction_definition = ExtractionDefinition.find(extraction_definition_id)
    harvest_definition = extraction_definition.harvest_definition
    return unless harvest_definition&.source_id

    Supplejack::JobCompletionSummaryLogger.log_completion(
      worker_class: 'EnrichmentExtractionWorker',
      exception: e,
      extraction_id: harvest_definition.source_id,
      extraction_name: harvest_definition.name,
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
