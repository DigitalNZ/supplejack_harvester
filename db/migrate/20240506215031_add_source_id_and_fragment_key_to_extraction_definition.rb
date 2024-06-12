# frozen_string_literal: true

class AddSourceIdAndFragmentKeyToExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :fragment_source_id, :string
    add_column :extraction_definitions, :fragment_key, :string
  end
end
