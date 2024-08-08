class SchemaFieldValue < ApplicationRecord

  validates :value, presence: true

  belongs_to :schema_field
  has_many :field_schema_field_values
  has_many :fields, through: :field_schema_field_values, dependent: :destroy

  def to_h
    {
      id:,
      schema_field_id:,
      value:,
      created_at:,
      updated_at:
    }
  end
end



