class RenamePreExtractionToIndependentExtraction < ActiveRecord::Migration[7.2]
  def change
    rename_column :automation_steps, :pre_extraction_job_id, :independent_extraction_job_id

    rename_column :extraction_definitions, :pre_extraction, :independent_extraction

    rename_column :extraction_jobs, :pre_extraction_job_id, :independent_extraction_job_id
    rename_column :extraction_jobs, :is_pre_extraction, :is_independent_extraction
  end
end
