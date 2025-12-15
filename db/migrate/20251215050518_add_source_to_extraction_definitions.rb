class AddSourceToExtractionDefinitions < ActiveRecord::Migration[7.0]
  def change
    add_reference :extraction_definitions, :source_extraction_definition,
                  foreign_key: { to_table: :extraction_definitions }, null: true
  end
end