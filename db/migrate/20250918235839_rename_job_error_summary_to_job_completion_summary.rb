class RenameJobErrorSummaryToJobCompletionSummary < ActiveRecord::Migration[7.2]
  def change
    # Check if the source table exists before attempting to rename
    if table_exists?(:job_error_summaries) && !table_exists?(:job_completion_summaries)
      rename_table :job_error_summaries, :job_completion_summaries
    elsif table_exists?(:job_completion_summaries)
      # Table already exists with correct name, no action needed
      puts "Table job_completion_summaries already exists, skipping rename"
    end
  end
end
