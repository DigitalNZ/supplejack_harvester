class RenameLastOccurredAtToLastCompletedAtInJobCompletionSummaries < ActiveRecord::Migration[7.2]
  def change
    rename_column :job_completion_summaries, :last_occurred_at, :last_completed_at
    
    # Rename the index as well
    remove_index :job_completion_summaries, :last_occurred_at
    add_index :job_completion_summaries, :last_completed_at
  end
end
