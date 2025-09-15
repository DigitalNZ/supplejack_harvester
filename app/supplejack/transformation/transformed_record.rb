# frozen_string_literal: true

module Transformation
  class TransformedRecord
    def initialize(fields, reject_fields = [], delete_fields = [])
      @fields = fields
      @reject_fields = reject_fields
      @delete_fields = delete_fields
    end

    def transformed_record
      @transformed_record ||= @fields.each_with_object({}) do |field, record|
        record[field.name] = field.value if field.error.nil?
      end
    end

    def errors
      @errors ||= @fields.each_with_object({}) do |field, errs|
        errs[field.id] = field.error.to_hash if field.error
      end
    end

    def reasons(fields)
      # Use filter_map if Ruby 2.7+ for concise mapping + filtering
      @reasons_cache ||= {}
      @reasons_cache[fields.object_id] ||= fields.filter_map { |field| field.name if field.value == true }
    end

    def to_hash
      {
        'transformed_record' => transformed_record,
        'errors' => errors,
        'rejection_reasons' => reasons(@reject_fields),
        'deletion_reasons' => reasons(@delete_fields)
      }
    end
  end
end
