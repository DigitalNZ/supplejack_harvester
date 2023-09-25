# frozen_string_literal: true

class AddTotalSelectorToExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :total_selector, :string
    add_column :extraction_definitions, :per_page, :integer
    add_column :extraction_definitions, :paginated, :boolean
  end
end
