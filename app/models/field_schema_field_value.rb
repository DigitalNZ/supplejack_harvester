# frozen_string_literal: true

# this is the join table between a field and it's associated schema field value

class FieldSchemaFieldValue < ApplicationRecord
  belongs_to :field
  belongs_to :schema_field_value

  def to_h
    {
      id:,
      field_id:,
      schema_field_value_id:,
      updated_at:,
      created_at:
    }
  end
end
