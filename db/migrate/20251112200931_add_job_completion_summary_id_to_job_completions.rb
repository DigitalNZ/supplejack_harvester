class AddJobCompletionSummaryIdToJobCompletions < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:job_completions, :job_completion_summary_id)
      add_column :job_completions, :job_completion_summary_id, :bigint, null: false
    end
    add_foreign_key :job_completions, :job_completion_summaries, on_delete: :cascade
    add_index :job_completions, :job_completion_summary_id
  end
end