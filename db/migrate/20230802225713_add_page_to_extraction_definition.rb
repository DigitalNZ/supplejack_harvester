# frozen_string_literal: true

class AddPageToExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :page, :integer, default: 1
  end
end
