# frozen_string_literal: true

class EnrichmentExtractionWorker
  include PerformWithPriority
  include Sidekiq::Job
  include Extraction::Concerns::EnrichmentExtractionProcess

  def perform(enrichment_params)
    process_enrichment_extraction(enrichment_params)
  rescue StandardError => e
    JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                  error: e,
                                                                  definition: enrichment_params.extraction_definition,
                                                                  job: enrichment_params.extraction_job,
                                                                  origin: 'EnrichmentExtractionWorker'
                                                                })
    raise
  end
end
