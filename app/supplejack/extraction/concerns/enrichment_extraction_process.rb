# frozen_string_literal: true

module Extraction
  module Concerns
    module EnrichmentExtractionProcess
      extend ActiveSupport::Concern

      included do
        def process_enrichment_extraction(enrichment_params)
          parsed_params = JSON.parse(enrichment_params)
          extraction_context = build_extraction_context(parsed_params)

          enrichment_extraction = extraction_context.enrichment_extraction
          return unless enrichment_extraction.valid?

          enrichment_extraction.extract_and_save
          handle_harvest_job(extraction_context)
        end
      end

      private

      ExtractionContext = Struct.new(
        :extraction_definition,
        :extraction_job,
        :enrichment_extraction,
        :harvest_job,
        :api_record,
        :page
      )

      # rubocop:disable Metrics/MethodLength
      def build_extraction_context(parsed_params)
        extraction_definition_id = parsed_params['extraction_definition_id']
        extraction_job_id = parsed_params['extraction_job_id']
        harvest_job_id = parsed_params['harvest_job_id']

        extraction_definition = ExtractionDefinition.find(extraction_definition_id)
        extraction_job = ExtractionJob.find(extraction_job_id)
        harvest_job = HarvestJob.find(harvest_job_id) if harvest_job_id.present?

        ExtractionContext.new(
          extraction_definition,
          extraction_job,
          build_enrichment_extraction(parsed_params, extraction_definition, extraction_job),
          harvest_job, parsed_params['api_record'], parsed_params['page']
        )
      end
      #rubocop:enable Metrics/MethodLength

      def build_enrichment_extraction(parsed_params, extraction_definition, extraction_job)
        Extraction::EnrichmentExtraction.new(
          extraction_definition.requests.last,
          Extraction::ApiRecord.new(parsed_params['api_record']),
          parsed_params['page'],
          extraction_job.extraction_folder
        )
      end

      def handle_harvest_job(extraction_context)
        return if extraction_context.harvest_job.blank?

        enqueue_record_transformation(extraction_context)
        update_harvest_report(extraction_context)
      end

      def enqueue_record_transformation(extraction_context)
        harvest_job = extraction_context.harvest_job
        enrichment_extraction = extraction_context.enrichment_extraction
        extraction_definition = extraction_context.extraction_definition

        return unless harvest_job.present? && enrichment_extraction.document.successful?
        return if extraction_definition.extract_text_from_file?

        TransformationWorker.perform_async(harvest_job.id,
                                           extraction_context.page,
                                           extraction_context.api_record['id'])

        harvest_report = harvest_job.harvest_report
        harvest_report.increment_transformation_workers_queued! if harvest_report.present?
      end

      def update_harvest_report(extraction_context)
        harvest_report = extraction_context.harvest_job.harvest_report
        return if harvest_report.blank?

        harvest_report.increment_pages_extracted!
        harvest_report.update(extraction_updated_time: Time.zone.now)
      end
    end
  end
end
