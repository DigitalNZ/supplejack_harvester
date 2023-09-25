# frozen_string_literal: true

class AddTokenisedFieldsToExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :next_token_path, :string
    add_column :extraction_definitions, :token_parameter, :string
    add_column :extraction_definitions, :token_value, :string
  end
end
