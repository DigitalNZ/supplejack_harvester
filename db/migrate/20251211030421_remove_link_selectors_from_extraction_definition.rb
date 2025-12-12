class RemoveLinkSelectorsFromExtractionDefinition < ActiveRecord::Migration[7.2]
  def change
    remove_column :extraction_definitions, :link_selectors, :text
  end
end
