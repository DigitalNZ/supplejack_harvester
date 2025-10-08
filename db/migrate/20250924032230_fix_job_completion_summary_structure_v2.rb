class FixJobCompletionSummaryStructureV2 < ActiveRecord::Migration[7.2]
  def change
    # Add new columns for process type and job type only if they don't exist
    add_column :job_completion_summaries, :process_type, :integer, null: false, default: 0 unless column_exists?(:job_completion_summaries, :process_type)
    add_column :job_completion_summaries, :job_type, :string, null: false unless column_exists?(:job_completion_summaries, :job_type)
    
    # Remove the old unique index on source_id if it exists
    remove_index :job_completion_summaries, :source_id if index_exists?(:job_completion_summaries, :source_id)
    
    # Add new unique index on source_id, process_type, and job_type only if it doesn't exist
    unless index_exists?(:job_completion_summaries, [:source_id, :process_type, :job_type], name: 'index_job_completion_summaries_on_source_process_job')
      add_index :job_completion_summaries, [:source_id, :process_type, :job_type], 
                unique: true, name: 'index_job_completion_summaries_on_source_process_job'
    end
    
    # Add index on process_type for queries only if it doesn't exist
    add_index :job_completion_summaries, :process_type unless index_exists?(:job_completion_summaries, :process_type)
  end
end
