# frozen_string_literal: true

class EnrichmentExtractionWorker
  include Sidekiq::Job
  include Extraction::Concerns::EnrichmentExtractionProcess

  def perform(extraction_definition_id, extraction_job_id, harvest_job_id, api_record, page)
    @extraction_definition = ExtractionDefinition.find(extraction_definition_id)
    @extraction_job = ExtractionJob.find(extraction_job_id)
    @harvest_job = HarvestJob.find(harvest_job_id)

    enrichment_extraction = Extraction::EnrichmentExtraction.new(@extraction_definition.requests.last, Extraction::ApiRecord.new(api_record), page, @extraction_job.extraction_folder)
    return unless enrichment_extraction.valid?

    enrichment_extraction.extract_and_save
    enqueue_record_transformation(@harvest_job, 
                                  @extraction_definition, 
                                  api_record, 
                                  enrichment_extraction.document, 
                                  page)

    update_harvest_report(@harvest_job.harvest_report)
  end
end