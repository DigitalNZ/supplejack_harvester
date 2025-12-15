class AddSourceToExtractionJobs < ActiveRecord::Migration[7.0]
  def change
    add_reference :extraction_jobs, :source_extraction_job,
                  foreign_key: { to_table: :extraction_jobs }, null: true
  end
end