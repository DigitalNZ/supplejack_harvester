# frozen_string_literal: true

class RawRecordSlice
  def initialize(transformation_definition, page, record)
    @page = (page || 1).to_i
    @record = (record || 1).to_i

    @job = transformation_definition.extraction_job
    @records = transformation_definition.records(@page)
  end

  def call
    {
      page: @page,
      record: @record,
      totalPages: @job.documents.total_pages,
      totalRecords: @records.length,
      format: @job.format,
      body: @records[@record - 1]
    }
  end
end
