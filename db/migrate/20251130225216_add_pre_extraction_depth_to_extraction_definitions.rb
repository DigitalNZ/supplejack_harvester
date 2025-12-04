# Migration to add depth field
# db/migrate/XXXXXX_add_pre_extraction_depth_to_extraction_definitions.rb
class AddPreExtractionDepthToExtractionDefinitions < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :pre_extraction_depth, :integer, default: 1
  end
end

