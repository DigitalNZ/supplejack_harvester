# frozen_string_literal: true

class ExtractionContext
  attr_reader :extraction_definition, :extraction_job, :enrichment_extraction, :harvest_job, :api_record, :page

  # rubocop:disable Metrics/ParameterLists
  def initialize(extraction_definition, extraction_job, enrichment_extraction, harvest_job, api_record, page)
    @extraction_definition = extraction_definition
    @extraction_job = extraction_job
    @enrichment_extraction = enrichment_extraction
    @harvest_job = harvest_job
    @api_record = api_record
    @page = page
  end
  # rubocop:enable Metrics/ParameterLists
end
