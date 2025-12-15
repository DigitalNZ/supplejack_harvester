class UpdateLinkSelectorsForMultiLevel < ActiveRecord::Migration[7.2]
  def up

    change_column :extraction_definitions, :link_selector, :text

    add_column :extraction_jobs, :extracted_links_by_depth, :text
  end

  def down
    change_column :extraction_definitions, :link_selector, :string
    remove_column :extraction_jobs, :extracted_links_by_depth
  end
end
