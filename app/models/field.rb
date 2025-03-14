# frozen_string_literal: true

class Field < ApplicationRecord
  KINDS = %w[field reject_if delete_if].freeze

  belongs_to :transformation_definition
  belongs_to :schema_field, optional: true

  # This is how a field refers to values associated with a schema field
  has_many :field_schema_field_values, dependent: :destroy
  has_many :schema_field_values, through: :field_schema_field_values, dependent: :destroy

  enum :kind, KINDS

  def schema?
    schema_field.present?
  end

  def name
    return super if schema_field.blank?

    schema_field.name
  end

  def block
    return super unless schema_field.present? && schema_field.fixed?

    if schema_field_values.count > 1
      schema_field_values.map(&:value).to_s
    elsif schema_field_values.count == 1
      "\"#{schema_field_values.first.value}\""
    else
      ''
    end
  end

  def to_h
    {
      id:, name:,
      block:, kind:,
      schema: schema?,
      schema_field_id: schema_field&.id,
      schema_field_kind: schema_field&.kind,
      field_schema_field_value_ids: field_schema_field_values.map(&:id),
      pipeline_id: transformation_definition.pipeline_id,
      created_at:, updated_at:
    }
  end
end
