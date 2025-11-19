class ChangeHarvestJobToHasManyExtractionJobs < ActiveRecord::Migration[7.2]
  def up
    # Add harvest_job_id to extraction_jobs (nullable, optional field)
    # This field is ONLY used for new multi-item extraction jobs
    # Existing extraction_jobs will have NULL harvest_job_id and continue using the old relationship
    add_column :extraction_jobs, :harvest_job_id, :bigint, null: true
    add_index :extraction_jobs, :harvest_job_id

    # DO NOT migrate existing data - leave existing extraction_jobs with NULL harvest_job_id
    # They will continue to work via the old harvest_jobs.extraction_job_id relationship
    # Only new multi-item extraction jobs will use extraction_jobs.harvest_job_id

    # Keep extraction_job_id on harvest_jobs for backward compatibility with existing jobs
    # New multi-item extraction jobs will use the has_many relationship via harvest_job_id
  end

  def down
    # Remove harvest_job_id from extraction_jobs
    remove_index :extraction_jobs, :harvest_job_id
    remove_column :extraction_jobs, :harvest_job_id
  end
end
