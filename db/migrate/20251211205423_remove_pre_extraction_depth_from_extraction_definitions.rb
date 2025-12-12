class RemovePreExtractionDepthFromExtractionDefinitions < ActiveRecord::Migration[7.2]
  def change
    remove_column :extraction_definitions, :pre_extraction_depth, :integer, default: 1
  end
end
