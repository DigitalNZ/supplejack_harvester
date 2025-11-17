class RemoveIncorrectJobCompletionsIndex < ActiveRecord::Migration[7.2]
  def change
    remove_index :job_completions,
                 [:process_type, :origin],
                 name: 'index_job_completions_on_source_process_origin_message',
                 if_exists: true
  end
end
