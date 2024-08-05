# frozen_string_literal: true

module Extraction
  module Concerns
    module EnrichmentExtractionProcess
      extend ActiveSupport::Concern

      included do
        def process_enrichment_extraction(enrichment_params)
          enrichment_extraction = build_enrichment_extraction(enrichment_params)
          return unless enrichment_extraction.valid?

          enrichment_extraction.extract_and_save
          handle_extraction_success(enrichment_extraction, enrichment_params)
        end
      end

      private

      def build_enrichment_extraction(enrichment_params)
        Extraction::EnrichmentExtraction.new(
          enrichment_params.extraction_definition.requests.last,
          Extraction::ApiRecord.new(enrichment_params.api_record),
          enrichment_params.page,
          enrichment_params.extraction_job.extraction_folder
        )
      end

      def handle_extraction_success(enrichment_extraction, enrichment_params)
        enqueue_record_transformation(enrichment_extraction, enrichment_params)
        update_harvest_report(enrichment_params)
      end

      def enqueue_record_transformation(enrichment_extraction, enrichment_params)
        return unless enrichment_params.harvest_job.present? && enrichment_extraction.document.successful?
        return if enrichment_params.extraction_definition.extract_text_from_file?

        TransformationWorker.perform_async(enrichment_params.harvest_job.id, enrichment_params.page, enrichment_params.api_record['id'])

        harvest_report = enrichment_params.harvest_job.harvest_report
        harvest_report.increment_transformation_workers_queued! if harvest_report.present?
      end

      def update_harvest_report(enrichment_params)
        return if enrichment_params.harvest_job.harvest_report.blank?

        enrichment_params.harvest_job.harvest_report.increment_pages_extracted!
        enrichment_params.harvest_job.harvest_report.update(extraction_updated_time: Time.zone.now)
      end
    end
  end
end
