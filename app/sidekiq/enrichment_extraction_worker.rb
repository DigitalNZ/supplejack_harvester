# frozen_string_literal: true

class EnrichmentExtractionWorker
  include Sidekiq::Job

  def perform(last_request, api_record, page, extraction_folder)
    enrichment_extraction = Extraction::EnrichmentExtraction.new(last_request, api_record, page, extraction_folder)

    enrichment_extraction.extract_and_save if enrichment_extraction.valid?
  end
end