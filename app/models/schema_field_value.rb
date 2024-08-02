class SchemaFieldValue < ApplicationRecord

  validates :name, presence: true

  belongs_to :schema_field
end
