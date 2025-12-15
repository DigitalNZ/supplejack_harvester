class AddLinkSelectorsToExtractionDefinitions < ActiveRecord::Migration[7.2]
  def change
    add_column :extraction_definitions, :link_selectors, :text unless column_exists?(:extraction_definitions, :link_selectors)
  end
end