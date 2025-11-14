class RemoveCompletionTypeFromJobCompletionSummaries < ActiveRecord::Migration[7.2]
  def change
    remove_index :job_completion_summaries, :completion_type if index_exists?(:job_completion_summaries, :completion_type)
    remove_column :job_completion_summaries, :completion_type, :integer
  end
end
