class UpdateJobCompletionsStructure < ActiveRecord::Migration[7.2]
  def change
    add_column :job_completions, :job_id, :bigint, null: false
    add_column :job_completions, :stop_condition_type, :string, null: false
    add_column :job_completions, :stop_condition_name, :string, null: false
    add_column :job_completions, :stop_condition_content, :text, null: false

    remove_column :job_completions, :source_id, :string, if_exists: true
    remove_column :job_completions, :source_name, :string, if_exists: true
    remove_column :job_completions, :message, :text, if_exists: true
    remove_column :job_completions, :message_prefix, :string, if_exists: true
    remove_column :job_completions, :stack_trace, :json, if_exists: true
    remove_column :job_completions, :details, :json, if_exists: true
    remove_column :job_completions, :job_type, :string, if_exists: true

    remove_index :job_completions, 
                 [:source_id, :process_type, :job_type, :origin, :message_prefix],
                 name: 'index_job_completions_on_source_process_origin_message',
                 if_exists: true
    remove_index :job_completions,
                 [:source_id, :process_type, :job_type],
                 name: 'index_job_completions_on_source_process_job',
                 if_exists: true

    add_index :job_completions,
              [:job_id, :origin, :stop_condition_name],
              unique: true,
              name: 'index_job_completions_on_job_origin_stop_condition'
    add_index :job_completions, :job_id
  end
end