class RemoveDepthColumnsFromExtractions < ActiveRecord::Migration[7.2]
  def change
    remove_column :extraction_jobs, :extracted_links_by_depth, :text
  end
end
