# frozen_string_literal: true

class ExtractionParams
  attr_reader :extraction_definition_id, :extraction_job_id, :harvest_job_id, :api_record, :page

  def initialize(extraction_definition_id, extraction_job_id, harvest_job_id, api_record, page)
    @extraction_definition_id = extraction_definition_id
    @extraction_job_id = extraction_job_id
    @harvest_job_id = harvest_job_id
    @api_record = api_record
    @page = page
  end
end
