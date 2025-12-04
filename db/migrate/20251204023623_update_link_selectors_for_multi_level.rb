class UpdateLinkSelectorsForMultiLevel < ActiveRecord::Migration[7.2]
  def up
    # Change link_selector from string to text to support longer selectors
    change_column :extraction_definitions, :link_selector, :text
    
    # Add extracted_links_by_depth to extraction_jobs for UI display
    add_column :extraction_jobs, :extracted_links_by_depth, :text
  end

  def down
    change_column :extraction_definitions, :link_selector, :string
    remove_column :extraction_jobs, :extracted_links_by_depth
  end
end
