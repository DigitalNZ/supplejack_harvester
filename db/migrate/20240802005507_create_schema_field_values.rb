class CreateSchemaFieldValues < ActiveRecord::Migration[7.1]
  def change
    create_table :schema_field_values do |t|
      t.text :name
      t.timestamps
    end

    add_reference :schema_field_values, :schema_field, null: false
  end
end
