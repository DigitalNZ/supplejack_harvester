class AddCompletionCountToJobCompletionSummaries < ActiveRecord::Migration[7.2]
  def change
    add_column :job_completion_summaries, :completion_count, :integer, default: 0, null: false
  end
end
