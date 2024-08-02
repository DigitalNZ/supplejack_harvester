class SchemaFieldValue < ApplicationRecord

  validates :value, presence: true

  belongs_to :schema_field
end
