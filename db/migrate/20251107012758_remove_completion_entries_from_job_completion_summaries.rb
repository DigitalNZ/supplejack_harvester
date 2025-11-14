class RemoveCompletionEntriesFromJobCompletionSummaries < ActiveRecord::Migration[7.2]
  def change
    remove_column :job_completion_summaries, :completion_entries, :json if column_exists?(:job_completion_summaries, :completion_entries)
  end
end
