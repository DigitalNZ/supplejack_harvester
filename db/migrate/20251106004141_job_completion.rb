class JobCompletion < ActiveRecord::Migration[7.2]
  def change
    # Check if table exists (might have been created by a later migration)
    if table_exists?(:job_completions)
      # Add columns if they don't exist
      add_column :job_completions, :source_id, :string, null: false unless column_exists?(:job_completions, :source_id)
      add_column :job_completions, :source_name, :string, null: false unless column_exists?(:job_completions, :source_name)
      add_column :job_completions, :origin, :string, after: :source_name unless column_exists?(:job_completions, :origin)
      add_column :job_completions, :job_type, :string, null: false unless column_exists?(:job_completions, :job_type)
      add_column :job_completions, :process_type, :integer, null: false unless column_exists?(:job_completions, :process_type)
      add_column :job_completions, :completion_type, :integer, null: false unless column_exists?(:job_completions, :completion_type)
      add_column :job_completions, :message, :text, null: false unless column_exists?(:job_completions, :message)
      add_column :job_completions, :message_prefix, :string, limit: 50, after: :message unless column_exists?(:job_completions, :message_prefix)
      add_column :job_completions, :stack_trace, :json, null: false unless column_exists?(:job_completions, :stack_trace)
      add_column :job_completions, :context, :json, null: false unless column_exists?(:job_completions, :context)
      add_column :job_completions, :details, :json, null: false unless column_exists?(:job_completions, :details)
      add_column :job_completions, :last_completed_at, :datetime unless column_exists?(:job_completions, :last_completed_at)
      
      # Populate message_prefix for existing records
      execute <<-SQL
        UPDATE job_completions 
        SET message_prefix = LEFT(message, 50)
        WHERE message_prefix IS NULL AND message IS NOT NULL
      SQL
    else
      # Create table if it doesn't exist
      create_table :job_completions do |t|
        t.string :source_id, null: false
        t.string :source_name, null: false
        t.string :origin
        t.string :job_type, null: false
        t.integer :process_type, null: false
        t.integer :completion_type, null: false
        t.text :message, null: false
        t.string :message_prefix, limit: 50
        t.json :stack_trace, null: false
        t.json :context, null: false
        t.json :details, null: false
        t.datetime :last_completed_at
        t.timestamps
      end
    end

    # Remove old unique index if it exists (will be replaced)
    if index_exists?(:job_completions, [:source_id, :process_type, :job_type], name: 'index_job_completions_on_source_process_job')
      remove_index :job_completions, name: 'index_job_completions_on_source_process_job'
    end
    
    # Remove old index with origin if it exists (will be replaced)
    if index_exists?(:job_completions, [:source_id, :process_type, :job_type, :origin], name: 'index_job_completions_on_source_process_job_origin')
      remove_index :job_completions, name: 'index_job_completions_on_source_process_job_origin'
    end
    
    # Add non-unique index for query performance
    unless index_exists?(:job_completions, [:source_id, :process_type, :job_type], name: 'index_job_completions_on_source_process_job')
      add_index :job_completions, 
                [:source_id, :process_type, :job_type],
                name: 'index_job_completions_on_source_process_job'
    end
    
    # Add unique composite index including message_prefix and origin
    unless index_exists?(:job_completions, [:source_id, :process_type, :job_type, :origin, :message_prefix], name: 'idx_jc_source_process_job_origin_msg')
      add_index :job_completions,
                [:source_id, :process_type, :job_type, :origin, :message_prefix],
                unique: true,
                name: 'idx_jc_source_process_job_origin_msg',
                length: { source_id: 100, job_type: 50, origin: 100, message_prefix: 50 }
    end
    
    add_index :job_completions, :last_completed_at unless index_exists?(:job_completions, :last_completed_at)
  end
end
