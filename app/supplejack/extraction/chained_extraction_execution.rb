# frozen_string_literal: true

module Extraction
  # Performs extraction by iterating over documents from a previous extraction job,
  # using dynamic parameters to build URLs from each document's data.
  class ChainedExtractionExecution
    def initialize(extraction_job)
      @extraction_job = extraction_job
      @extraction_definition = extraction_job.extraction_definition
      @source_job = extraction_job.source_extraction_job
    end

    def call
      DocumentIterator.new(@source_job).each do |record_data, page|
        break if @extraction_job.reload.cancelled?

        process_document(record_data, page)
        throttle
      end
    rescue StandardError => e
      handle_error(e)
    end

    private

    def process_document(record_data, page)
      @extraction_definition.page = page

      extraction = EnrichmentExtraction.new(
        @extraction_definition.requests.last,
        ApiRecord.new(record_data),
        page,
        @extraction_job.extraction_folder
      )

      return unless extraction.valid?

      extraction.extract_and_save
    end

    def throttle
      sleep @extraction_definition.throttle / 1000.0
    end

    def handle_error(error)
      JobCompletionServices::ContextBuilder.create_job_completion_or_error(
        error: error,
        definition: @extraction_definition,
        job: @extraction_job,
        origin: 'ChainedExtractionExecution'
      )
      raise
    end
  end
end
