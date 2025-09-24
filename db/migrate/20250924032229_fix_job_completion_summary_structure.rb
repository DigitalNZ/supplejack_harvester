class FixJobCompletionSummaryStructure < ActiveRecord::Migration[7.2]
  def change
    # Rename completion_entries to completion_entries
    rename_column :job_completion_summaries, :completion_entries, :completion_entries
    
    # Add new columns for process type and job type
    add_column :job_completion_summaries, :process_type, :integer, null: false, default: 0
    add_column :job_completion_summaries, :job_type, :string, null: false
    
    # Remove the old unique index on extraction_id if it exists
    remove_index :job_completion_summaries, :source_id if index_exists?(:job_completion_summaries, :source_id)
    
    # Add new unique index on source_id, process_type, and job_type
    add_index :job_completion_summaries, [:source_id, :process_type, :job_type], 
              unique: true, name: 'index_job_completion_summaries_on_source_process_job'
    
    # Add index on process_type for queries
    add_index :job_completion_summaries, :process_type
  end
end
