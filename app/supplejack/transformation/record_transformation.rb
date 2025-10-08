# frozen_string_literal: true

module Transformation
  # This class performs the transformation of a single record
  # It provides details about the execution of the transformation
  # such as errors and transformation results
  class RecordTransformation
    def initialize(extracted_record, fields)
      @extracted_record = extracted_record

      # Group fields by kind and pre-instantiate FieldExecution objects
      @fields_by_kind = fields.group_by(&:kind).transform_values do |fields_array|
        fields_array.map { |field| FieldExecution.new(field) }
      end
    end

    def transform
      reject_results = execute_fields('reject_if')
      delete_results = execute_fields('delete_if')
      field_results  = execute_fields('field')

      TransformedRecord.new(field_results, reject_results, delete_results)
    end

    private

    def execute_fields(kind)
      (@fields_by_kind[kind] || []).map { |field_exec| field_exec.execute(@extracted_record) }
    end
  end
end
