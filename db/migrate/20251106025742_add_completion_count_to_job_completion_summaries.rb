class AddCompletionCountToJobCompletionSummaries < ActiveRecord::Migration[7.2]
  def change
    # Consolidated: Remove and re-add completion_count to ensure correct definition
    # If it exists, remove it first (from 20251106013234)
    if column_exists?(:job_completion_summaries, :completion_count)
      remove_column :job_completion_summaries, :completion_count
    end
    
    # Add it back with correct definition (from 20251106025742)
    add_column :job_completion_summaries, :completion_count, :integer, default: 0, null: false
  end
end

