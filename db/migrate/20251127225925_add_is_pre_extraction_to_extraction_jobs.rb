class AddIsPreExtractionToExtractionJobs < ActiveRecord::Migration[7.2]
  def change
    add_column :extraction_jobs, :is_pre_extraction, :boolean, default: nil, null: true
  end
end
