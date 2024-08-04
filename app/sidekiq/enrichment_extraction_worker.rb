# frozen_string_literal: true

class EnrichmentExtractionWorker
  include Sidekiq::Job

  def perform(extraction_definition, extraction_job, api_record, page)
    enrichment_extraction = Extraction::EnrichmentExtraction.new(extraction_definition.requests.last, api_record, page, extraction_job.extraction_folder)
    return unless enrichment_extraction.valid?

    enrichment_extraction.extract_and_save
    enqueue_record_transformation(extraction_job.harvest_job, 
                                  extraction_definition, 
                                  api_record, 
                                  enrichment_extraction.document, 
                                  page)
  end

  private

    def enqueue_record_transformation(harvest_job, extraction_definition, api_record, document, page)
      return unless harvest_job.present? && document.successful?
      return if extraction_definition.extract_text_from_file?

      TransformationWorker.perform_async(harvest_job.id, page, api_record['id'])
      harvest_job.harvest_report.increment_transformation_workers_queued! if harvest_job.harvest_report.present?
    end
end