# frozen_string_literal: true

module Extraction
  module Concerns
    module EnrichmentExtractionProcess
      extend ActiveSupport::Concern

      included do
        def process_enrichment_extraction(extraction_definition_id, extraction_job_id, harvest_job_id, api_record, page)
          extraction_definition = ExtractionDefinition.find(extraction_definition_id)
          extraction_job = ExtractionJob.find(extraction_job_id)
          harvest_job = HarvestJob.find(harvest_job_id)

          enrichment_extraction = Extraction::EnrichmentExtraction.new(extraction_definition.requests.last,
                                                                       Extraction::ApiRecord.new(api_record), page, 
                                                                       extraction_job.extraction_folder)
          return unless enrichment_extraction.valid?

          enrichment_extraction.extract_and_save
          enqueue_record_transformation(harvest_job,
                                        extraction_definition,
                                        api_record,
                                        enrichment_extraction.document,
                                        page)

          update_harvest_report(harvest_job.harvest_report)
        end
      end

      private

      def enqueue_record_transformation(harvest_job, extraction_definition, api_record, document, page)
        return unless harvest_job.present? && document.successful?
        return if extraction_definition.extract_text_from_file?

        TransformationWorker.perform_async(harvest_job.id, page, api_record['id'])

        harvest_report = harvest_job.harvest_report
        harvest_report.increment_transformation_workers_queued! if harvest_report.present?
      end

      def update_harvest_report(harvest_report)
        return if harvest_report.blank?

        harvest_report.increment_pages_extracted!
        harvest_report.update(extraction_updated_time: Time.zone.now)
      end
    end
  end
end
