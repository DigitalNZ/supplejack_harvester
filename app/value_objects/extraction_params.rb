# frozen_string_literal: true

class ExtractionParams
  attr_reader :extraction_definition, :extraction_job, :harvest_job, :api_record, :page

  def initialize(extraction_definition, extraction_job, harvest_job, api_record, page)
    @extraction_definition = extraction_definition
    @extraction_job = extraction_job
    @harvest_job = harvest_job
    @api_record = api_record
    @page = page
  end
end