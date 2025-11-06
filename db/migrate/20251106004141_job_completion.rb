class JobCompletion < ActiveRecord::Migration[7.2]
  def change
    # Check if table exists (might have been created by a later migration)
    if table_exists?(:job_completions)
      # Add columns if they don't exist
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
    else
      # Create table if it doesn't exist
      create_table :job_completions do |t|
        t.string :source_id, null: false
        t.string :source_name, null: false
        t.string :job_type, null: false
        t.integer :process_type, null: false
        t.integer :completion_type, null: false
        t.text :message, null: false
        t.json :stack_trace, null: false
        t.json :context, null: false
        t.json :details, null: false
        t.datetime :last_completed_at
        t.timestamps
      end
    end

    # Add indexes if they don't exist
    unless index_exists?(:job_completions, [:source_id, :process_type, :job_type])
      add_index :job_completions, [:source_id, :process_type, :job_type], 
                unique: true, name: 'index_job_completions_on_source_process_job'
    end
    add_index :job_completions, :last_completed_at unless index_exists?(:job_completions, :last_completed_at)
  end
end
