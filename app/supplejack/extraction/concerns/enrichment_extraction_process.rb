# frozen_string_literal: true

module Extraction
  module Concerns
    module EnrichmentExtractionProcess
      extend ActiveSupport::Concern

      included do
        def process_enrichment_extraction(enrichment_params)
          parsed_params = JSON.parse(enrichment_params)

          extraction_definition = ExtractionDefinition.find(parsed_params['extraction_definition_id'])
          extraction_job = ExtractionJob.find(parsed_params['extraction_job_id'])
          harvest_job = HarvestJob.find(parsed_params['harvest_job_id'])

          enrichment_extraction = build_enrichment_extraction(parsed_params, extraction_definition, extraction_job)
          return unless enrichment_extraction.valid?

          enrichment_extraction.extract_and_save
          enqueue_record_transformation(enrichment_extraction, extraction_definition, parsed_params, harvest_job)
          update_harvest_report(harvest_job)
        end
      end

      private

      def build_enrichment_extraction(parsed_params, extraction_definition, extraction_job)
        Extraction::EnrichmentExtraction.new(
          extraction_definition.requests.last,
          Extraction::ApiRecord.new(parsed_params['api_record']),
          parsed_params['page'],
          extraction_job.extraction_folder
        )
      end

      def enqueue_record_transformation(enrichment_extraction, extraction_definition, parsed_params, harvest_job)
        return unless harvest_job.present? && enrichment_extraction.document.successful?
        return if extraction_definition.extract_text_from_file?

        TransformationWorker.perform_async(harvest_job.id, parsed_params['page'], parsed_params['api_record']['id'])

        harvest_report = harvest_job.harvest_report
        harvest_report.increment_transformation_workers_queued! if harvest_report.present?
      end

      def update_harvest_report(harvest_job)
        return unless harvest_job&.harvest_report
      
        harvest_report = harvest_job.harvest_report
        harvest_report.increment_pages_extracted!
        harvest_report.update(extraction_updated_time: Time.zone.now)
      end
    end
  end
end
