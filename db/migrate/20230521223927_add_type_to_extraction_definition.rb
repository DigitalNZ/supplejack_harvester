# frozen_string_literal: true

class AddTypeToExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :kind, :integer, default: 0
  end
end
