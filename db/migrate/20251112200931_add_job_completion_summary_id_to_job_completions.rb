class AddJobCompletionSummaryIdToJobCompletions < ActiveRecord::Migration[7.2]
  def change
    add_column :job_completions, :job_completion_summary_id, :bigint, null: false
    add_foreign_key :job_completions, :job_completion_summaries, on_delete: :cascade
    add_index :job_completions, :job_completion_summary_id
  end
end
