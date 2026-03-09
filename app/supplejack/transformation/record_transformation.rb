# frozen_string_literal: true

module Transformation
  # This class performs the transformation of a single record
  # It provides details about the execution of the transformation
  # such as errors and transformation results
  class RecordTransformation
    def initialize(extracted_record, fields, harvest_job: nil)
      @extracted_record = extracted_record
      @fields = fields.select { |field| field.kind == 'field' }
      @reject_conditions = fields.select { |field| field.kind == 'reject_if' }
      @delete_conditions = fields.select { |field| field.kind == 'delete_if' }
      @harvest_job = harvest_job
    end

    def transform
      reject_fields = @reject_conditions.map do |field|
        FieldExecution.new(field, harvest_job: @harvest_job).execute(@extracted_record)
      end

      delete_fields = @delete_conditions.map do |field|
        FieldExecution.new(field, harvest_job: @harvest_job).execute(@extracted_record)
      end

      transformed_fields = @fields.map do |field|
        FieldExecution.new(field, harvest_job: @harvest_job).execute(@extracted_record)
      end

      TransformedRecord.new(transformed_fields, reject_fields, delete_fields)
    end
  end
end
