class RemoveCompletionTypeFromJobCompletions < ActiveRecord::Migration[7.2]
  def change
    remove_index :job_completions, :completion_type if index_exists?(:job_completions, :completion_type)
    remove_column :job_completions, :completion_type, :integer
  end
end
