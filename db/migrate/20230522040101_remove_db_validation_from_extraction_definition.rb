# frozen_string_literal: true

class RemoveDbValidationFromExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    change_column :extraction_definitions, :format, :string, null: true
    change_column :extraction_definitions, :base_url, :string, null: true
    change_column :extraction_definitions, :pagination_type, :string, null: true
  end
end
