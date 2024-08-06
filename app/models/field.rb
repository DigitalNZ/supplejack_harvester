# frozen_string_literal: true

class Field < ApplicationRecord
  KINDS = %w[field reject_if delete_if].freeze

  belongs_to :transformation_definition
  belongs_to :schema_field, optional: true
  belongs_to :schema_field_value, optional: true
  has_and_belongs_to_many :schema_field_values

  enum :kind, KINDS

  def schema?
    schema_field.present?
  end

  def name
    return super unless schema_field.present?

    schema_field.name
  end

  def block
    return super unless schema_field.present? && schema_field.fixed?

    if schema_field_values.count > 1
      schema_field_values.map(&:value)
    elsif schema_field_values.count == 1
      "\"#{schema_field_values.first.value}\"" 
    else 
      ''
    end
  end

  def to_h
    {
      id:,
      name:,
      block:,
      kind:,
      schema: schema?,
      schema_field_id: schema_field&.id,
      schema_field_kind: schema_field&.kind,
      schema_field_values: schema_field_values.map(&:id),
      created_at:,
      updated_at:
    }
  end
end
