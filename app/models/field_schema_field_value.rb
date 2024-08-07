# this is the join table between a field and it's associated schema field value

class FieldSchemaFieldValue < ApplicationRecord
  belongs_to :field
  belongs_to :schema_field_value
end
