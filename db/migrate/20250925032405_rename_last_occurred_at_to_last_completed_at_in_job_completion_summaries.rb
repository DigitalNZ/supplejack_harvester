class RenameLastOccurredAtToLastCompletedAtInJobCompletionSummaries < ActiveRecord::Migration[7.2]
  def change
    # Only rename if the old column exists and new column doesn't exist
    if column_exists?(:job_completion_summaries, :last_occurred_at) && !column_exists?(:job_completion_summaries, :last_completed_at)
      rename_column :job_completion_summaries, :last_occurred_at, :last_completed_at
      
      # Rename the index as well, but only if it exists
      if index_exists?(:job_completion_summaries, :last_occurred_at)
        remove_index :job_completion_summaries, :last_occurred_at
      end
    end
    
    # Add index on last_completed_at if it doesn't exist
    add_index :job_completion_summaries, :last_completed_at unless index_exists?(:job_completion_summaries, :last_completed_at)
  end
end
