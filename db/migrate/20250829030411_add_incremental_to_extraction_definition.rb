class AddIncrementalToExtractionDefinition < ActiveRecord::Migration[7.1]
  def change
    add_column :extraction_definitions, :incremental, :boolean, default: false
  end
end
