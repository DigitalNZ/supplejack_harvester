# frozen_string_literal: true

class AddEnrichmentFieldsToExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :source_id, :string
    add_column :extraction_definitions, :enrichment_url, :string

    add_reference :extraction_definitions, :destination
  end
end
