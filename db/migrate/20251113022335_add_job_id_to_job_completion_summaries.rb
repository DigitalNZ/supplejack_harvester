class AddJobIdToJobCompletionSummaries < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:job_completion_summaries, :job_id)
      add_column :job_completion_summaries, :job_id, :bigint, null: false
    end

    remove_index :job_completion_summaries, 
                  [:source_id, :process_type, :job_type], 
                  name: 'index_job_completion_summaries_on_source_process_job',
                  if_exists: true

    add_index :job_completion_summaries, 
              [:job_id, :process_type, :job_type], 
              unique: true,
              name: 'index_job_completion_summaries_on_job_process_type'

    change_column_null :job_completion_summaries, :source_id, true
    change_column_null :job_completion_summaries, :source_name, true
  end
end