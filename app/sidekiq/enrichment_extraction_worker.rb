# frozen_string_literal: true

class EnrichmentExtractionWorker
  include Sidekiq::Job
  include Extraction::Concerns::EnrichmentExtractionProcess

  def perform(extraction_definition_id, extraction_job_id, harvest_job_id, api_record, page)
    process_enrichment_extraction(extraction_definition_id, extraction_job_id, harvest_job_id, api_record, page)
  end
end