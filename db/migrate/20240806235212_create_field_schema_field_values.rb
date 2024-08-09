# frozen_string_literal: true

class CreateFieldSchemaFieldValues < ActiveRecord::Migration[7.1]
  def change
    create_table :field_schema_field_values do |t|
      t.references :field, null: false, foreign_key: true
      t.references :schema_field_value, null: false, foreign_key: true

      t.timestamps
    end
  end
end
