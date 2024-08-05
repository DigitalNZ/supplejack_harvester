class SchemaFieldValue < ApplicationRecord

  validates :value, presence: true

  belongs_to :schema_field
  has_and_belongs_to_many :fields

  def to_h
    {
      id:,
      value:,
      created_at:,
      updated_at:
    }
  end
end
