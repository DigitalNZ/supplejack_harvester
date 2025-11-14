class RemoveSourceFieldsFromJobCompletionSummaries < ActiveRecord::Migration[7.2]
  def change
    remove_column :job_completion_summaries, :source_id, :string, if_exists: true
    remove_column :job_completion_summaries, :source_name, :string, if_exists: true
  end
end