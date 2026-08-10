# frozen_string_literal: true

module Extraction
  class EnrichmentExecution
    include Extraction::Concerns::EnrichmentExtractionProcess

    def initialize(extraction_job)
      @extraction_job = extraction_job
      @extraction_definition = extraction_job.extraction_definition
      @harvest_job = extraction_job.harvest_job
      @harvest_report = @harvest_job.harvest_report if @harvest_job.present?
      @records_consumed = 0
    end

    def call
      iterator.each do |api_document, page|
        break if api_document.body.blank?

        process_enrichment_page(api_document, page)
      end
    rescue StandardError => e
      handle_enrichment_error(e)
    end

    def process_enrichment_page(api_document, page)
      @extraction_definition.page = page
      api_records = JSON.parse(api_document.body)['records']
      extract_and_save_enrichment_documents(api_records)
      @records_consumed += api_records.size
    end

    def handle_enrichment_error(error)
      JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                             error: error,
                                                                             definition: @extraction_definition,
                                                                             job: @extraction_job,
                                                                             origin: 'EnrichmentExecution'
                                                                           })
      raise
    end

    private

    def iterator
      folder = preprocess_folder
      return SjApiEnrichmentIterator.new(@extraction_job) if folder.blank?

      # A sample takes the first page of stored records rather than all of them.
      PreProcessRecordIterator.new(folder, pages: (1 if @extraction_job.is_sample?))
    end

    # The folder of records this extraction works from, or nil when it seeds itself
    # from the destination API.
    def preprocess_folder
      # Started on its own from the block's dropdown: it was told which earlier run to
      # work from, because there is no run of its own to take it from.
      return @extraction_job.preprocess_output_folder if @extraction_job.iterates_preprocess_output?

      definition = @harvest_job&.harvest_definition
      return if definition.blank? || !definition.consumes_preprocess_output?

      # Usually this run's own output from the preceding block, but a run configured to
      # reuse pre-processed data prepared earlier reads another run's folder.
      source_job_id = @harvest_job.pipeline_job.preprocess_source_job_id(definition)
      PreProcess::Output.folder(source_job_id, definition.preceding_position)
    end

    def extract_and_save_enrichment_documents(api_records)
      api_records.each_with_index do |api_record, index|
        enrichment_params = ExtractionParams.new(@extraction_definition.id,
                                                 @extraction_job.id,
                                                 @harvest_job&.id,
                                                 api_record,
                                                 page_from_index(index))
        process_enrichment(enrichment_params)

        break if extraction_cancelled?
      end
    end

    def extraction_cancelled?
      @extraction_job.reload.cancelled?
    end

    def process_enrichment(enrichment_params)
      json_params = enrichment_params.to_json

      if @harvest_job&.pipeline_job&.run_enrichment_concurrently?
        EnrichmentExtractionWorker.perform_async_with_priority(@harvest_job.pipeline_job.job_priority, json_params)
      else
        throttle
        process_enrichment_extraction(json_params)
      end
    end

    def throttle
      sleep @extraction_definition.throttle / 1000.0
    end

    def page_from_index(index)
      # Page numbers name the saved document files, so they must be unique
      # across the whole job — a repeated page silently overwrites an earlier
      # record. Sources without per_page (e.g. preprocess output spanning
      # multiple documents) can't derive an offset from pagination, so they
      # use a running count of records consumed instead.
      per_page = @extraction_definition.per_page
      return @records_consumed + index + 1 if per_page.nil?

      ((@extraction_definition.page - 1) * per_page) + (index + 1)
    end
  end
end
