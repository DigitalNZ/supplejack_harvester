class AddColumnsToJobCompletions < ActiveRecord::Migration[7.2]
  def change
    add_column :job_completions, :source_id, :string, null: false unless column_exists?(:job_completions, :source_id)
    add_column :job_completions, :source_name, :string, null: false unless column_exists?(:job_completions, :source_name)
    add_column :job_completions, :job_type, :string, null: false unless column_exists?(:job_completions, :job_type)
    add_column :job_completions, :process_type, :integer, null: false unless column_exists?(:job_completions, :process_type)
    add_column :job_completions, :completion_type, :integer, null: false unless column_exists?(:job_completions, :completion_type)
    add_column :job_completions, :message, :text, null: false unless column_exists?(:job_completions, :message)
    add_column :job_completions, :stack_trace, :json, null: false unless column_exists?(:job_completions, :stack_trace)
    add_column :job_completions, :context, :json, null: false unless column_exists?(:job_completions, :context)
    add_column :job_completions, :details, :json, null: false unless column_exists?(:job_completions, :details)
    add_column :job_completions, :last_completed_at, :datetime unless column_exists?(:job_completions, :last_completed_at)

    unless index_exists?(:job_completions, [:source_id, :process_type, :job_type])
      add_index :job_completions, [:source_id, :process_type, :job_type], 
                unique: true, name: 'index_job_completions_on_source_process_job'
    end
    add_index :job_completions, :last_completed_at unless index_exists?(:job_completions, :last_completed_at)
  end
end
