class CreateSchemaFields < ActiveRecord::Migration[7.1]
  def change
    create_table :schema_fields do |t|
      t.text :name
      t.timestamps
    end

    add_reference :schema_fields, :schema, null: false
  end
end
