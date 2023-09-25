# frozen_string_literal: true

class RemoveUnnecessaryFieldsFromExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    remove_column :extraction_definitions, :page_parameter
    remove_column :extraction_definitions, :per_page_parameter
    remove_column :extraction_definitions, :page
    remove_column :extraction_definitions, :per_page
    remove_column :extraction_definitions, :total_selector
    remove_column :extraction_definitions, :next_token_path
    remove_column :extraction_definitions, :token_parameter
    remove_column :extraction_definitions, :token_value
    remove_column :extraction_definitions, :initial_params
  end
end
