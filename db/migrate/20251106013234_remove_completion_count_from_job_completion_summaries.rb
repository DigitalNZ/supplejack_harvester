class RemoveCompletionCountFromJobCompletionSummaries < ActiveRecord::Migration[7.2]
  def change
    remove_column :job_completion_summaries, :completion_count, :integer
  end
end
