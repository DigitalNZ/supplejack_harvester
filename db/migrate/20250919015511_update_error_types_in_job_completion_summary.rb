class UpdateErrorTypesInJobCompletionSummary < ActiveRecord::Migration[7.2]
  def up
    # Update existing records to use new error type labels
    execute "UPDATE job_completion_summaries SET error_type = 'error' WHERE error_type = 'unplanned'"
    execute "UPDATE job_completion_summaries SET error_type = 'stop condition' WHERE error_type = 'planned'"
  end

  def down
    # Revert back to old error type labels
    execute "UPDATE job_completion_summaries SET error_type = 'unplanned' WHERE error_type = 'error'"
    execute "UPDATE job_completion_summaries SET error_type = 'planned' WHERE error_type = 'stop condition'"
  end
end