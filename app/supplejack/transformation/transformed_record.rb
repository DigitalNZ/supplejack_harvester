# frozen_string_literal: true

module Transformation
  # This class performs the transformation of a single record
  # It provides details about the execution of the transformation
  # such as errors and transformation results
  class TransformedRecord
    def initialize(fields)
      @fields = fields
    end

    def transformed_record
      @fields.each_with_object({}) do |field, transformed_record|
        transformed_record[field.name] = field.value if field.error.nil?
      end
    end

    def errors
      @fields.each_with_object({}) do |field, errors|
        errors[field.id] = field.error.to_hash if field.error.present?
      end
    end

    def to_hash
      {
        'transformed_record' => transformed_record,
        'errors' => errors
      }
    end
  end
end
