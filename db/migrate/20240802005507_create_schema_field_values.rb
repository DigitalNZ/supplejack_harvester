# frozen_string_literal: true

class CreateSchemaFieldValues < ActiveRecord::Migration[7.1]
  def change
    create_table :schema_field_values do |t|
      t.text :value
      t.timestamps
    end

    # Disabling this cop as this is a relationship table
    # rubocop:disable Rails/NotNullColumn
    add_reference :schema_field_values, :schema_field, null: false
    # rubocop:enable Rails/NotNullColumn
  end
end
