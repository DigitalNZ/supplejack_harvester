# frozen_string_literal: true

module Transformation
  # This class performs the transformation of a single record
  # It provides details about the execution of the transformation
  # such as errors and transformation results
  class RecordTransformation
    def initialize(extracted_record, fields, harvest_job: nil)
      @extracted_record = extracted_record
      grouped = fields.group_by(&:kind)
      @fields = grouped['field'] || []
      @reject_conditions = grouped['reject_if'] || []
      @delete_conditions = grouped['delete_if'] || []
      @harvest_job = harvest_job
    end

    def transform
      reject_fields = execute_fields(@reject_conditions)
      delete_fields = execute_fields(@delete_conditions)
      transformed_fields = execute_fields(@fields)

      TransformedRecord.new(transformed_fields, reject_fields, delete_fields)
    end

    private

    def execute_fields(fields)
      fields.map { |field| execute_field(field) }
    end

    def execute_field(field)
      FieldExecution.new(field, harvest_job: @harvest_job).execute(@extracted_record)
    end
  end
end
