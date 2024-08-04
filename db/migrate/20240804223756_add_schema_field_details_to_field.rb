class AddSchemaFieldDetailsToField < ActiveRecord::Migration[7.1]
  def change
    add_reference :fields, :schema_field
    add_reference :fields, :schema_field_value
  end
end
