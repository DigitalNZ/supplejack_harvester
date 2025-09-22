class FixJobCompletionSummaryColumns < ActiveRecord::Migration[7.2]
  def up
    # Rename error fields to completion fields
    rename_column :job_completion_summaries, :error_type, :completion_type
    rename_column :job_completion_summaries, :error_details, :completion_details
    rename_column :job_completion_summaries, :error_count, :completion_count
    
    # Remove the old timestamp columns
    remove_column :job_completion_summaries, :first_error_at
    remove_column :job_completion_summaries, :last_error_at
    
    # Add the new timestamp column
    add_column :job_completion_summaries, :last_occurred_at, :datetime
    
    # Update indexes
    remove_index :job_completion_summaries, :error_type if index_exists?(:job_completion_summaries, :error_type)
    add_index :job_completion_summaries, :completion_type unless index_exists?(:job_completion_summaries, :completion_type)
    remove_index :job_completion_summaries, :first_error_at if index_exists?(:job_completion_summaries, :first_error_at)
    remove_index :job_completion_summaries, :last_error_at if index_exists?(:job_completion_summaries, :last_error_at)
    add_index :job_completion_summaries, :last_occurred_at unless index_exists?(:job_completion_summaries, :last_occurred_at)
  end

  def down
    # Reverse the changes
    rename_column :job_completion_summaries, :completion_type, :error_type
    rename_column :job_completion_summaries, :completion_details, :error_details
    rename_column :job_completion_summaries, :completion_count, :error_count
    
    # Add back the old timestamp columns
    add_column :job_completion_summaries, :first_error_at, :datetime
    add_column :job_completion_summaries, :last_error_at, :datetime
    
    # Remove the new timestamp column
    remove_column :job_completion_summaries, :last_occurred_at
    
    # Update indexes back
    remove_index :job_completion_summaries, :completion_type if index_exists?(:job_completion_summaries, :completion_type)
    add_index :job_completion_summaries, :error_type
    remove_index :job_completion_summaries, :last_occurred_at if index_exists?(:job_completion_summaries, :last_occurred_at)
    add_index :job_completion_summaries, :first_error_at
    add_index :job_completion_summaries, :last_error_at
  end
end
