class AddKindToSchemaField < ActiveRecord::Migration[7.1]
  def change
    add_column :schema_fields, :kind, :integer, default: 0
  end
end
