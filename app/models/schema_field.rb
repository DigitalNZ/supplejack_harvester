class SchemaField < ApplicationRecord
  belongs_to :schema
  has_many :schema_field_values, dependent: :destroy
  has_many :fields, dependent: :destroy

  enum :kind, { dynamic: 0, fixed: 1 }

  def to_h
    {
      id:,
      name:,
      kind:,
      schema_field_value_ids: schema_field_values.map(&:id),
      referenced_pipelines: fields.map(&:transformation_definition).map(&:pipeline).uniq.map(&:to_h),
      created_at:,
      updated_at:
    }
  end
end
