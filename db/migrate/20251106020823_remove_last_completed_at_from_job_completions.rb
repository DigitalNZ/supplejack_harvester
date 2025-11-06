class RemoveLastCompletedAtFromJobCompletions < ActiveRecord::Migration[7.2]
  def change
    # Remove from job_completion_summaries
    remove_index :job_completion_summaries, :last_completed_at if index_exists?(:job_completion_summaries, :last_completed_at)
    remove_column :job_completion_summaries, :last_completed_at if column_exists?(:job_completion_summaries, :last_completed_at)
    
    # Remove from job_completions
    remove_index :job_completions, :last_completed_at if index_exists?(:job_completions, :last_completed_at)
    remove_column :job_completions, :last_completed_at if column_exists?(:job_completions, :last_completed_at)
  end
end
