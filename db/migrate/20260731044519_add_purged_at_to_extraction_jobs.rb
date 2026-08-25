# frozen_string_literal: true

class AddPurgedAtToExtractionJobs < ActiveRecord::Migration[8.0]
  def change
    add_column :extraction_jobs, :purged_at, :datetime
    add_index :extraction_jobs, :purged_at
  end
end
