class CreateJoinTableFieldsSchemaFieldValues < ActiveRecord::Migration[7.1]
  def change
    create_join_table :fields, :schema_field_values do |t|
      t.index [:field_id, :schema_field_value_id]
      t.index [:schema_field_value_id, :field_id]
    end
  end
end
