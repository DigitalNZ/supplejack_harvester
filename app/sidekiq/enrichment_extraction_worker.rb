# frozen_string_literal: true

class EnrichmentExtractionWorker
  include PerformWithPriority
  include Sidekiq::Job
  include Extraction::Concerns::EnrichmentExtractionProcess

  def perform(enrichment_params)
    process_enrichment_extraction(enrichment_params)
  rescue StandardError => error
    Supplejack::JobCompletionSummaryLogger.log_enrichment_extraction_completion(
      exception: error,
      enrichment_params: enrichment_params
    )
    raise
  end
end
