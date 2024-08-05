# frozen_string_literal: true

class Field < ApplicationRecord
  KINDS = %w[field reject_if delete_if].freeze

  belongs_to :transformation_definition
  belongs_to :schema_field, optional: true
  belongs_to :schema_field_value, optional: true

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

    schema_field_value&.value || ''
  end

  def to_h
    {
      id:,
      name:,
      block:,
      kind:,
      schema: schema?,
      schema_field_kind: schema_field&.kind,
      created_at:,
      updated_at:
    }
  end
end
