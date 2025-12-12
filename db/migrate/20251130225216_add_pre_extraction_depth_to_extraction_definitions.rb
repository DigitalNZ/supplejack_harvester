class AddPreExtractionDepthToExtractionDefinitions < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :pre_extraction_depth, :integer, default: 1
  end
end

