# frozen_string_literal: true

class CreateSchemaFields < ActiveRecord::Migration[7.1]
  def change
    create_table :schema_fields do |t|
      t.text :name
      t.timestamps
    end

    # Disabling this cop as this is a relationship table
    # rubocop:disable Rails/NotNullColumn
    add_reference :schema_fields, :schema, null: false
    # rubocop:enable Rails/NotNullColumn
  end
end
