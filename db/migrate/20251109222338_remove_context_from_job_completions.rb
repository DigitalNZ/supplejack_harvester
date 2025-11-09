class RemoveContextFromJobCompletions < ActiveRecord::Migration[7.2]
  def change
    remove_column :job_completions, :context, :json
  end
end
