class AddMessagePrefixToJobCompletions < ActiveRecord::Migration[7.2]
  def up
    # Add message_prefix column if it doesn't exist
    unless column_exists?(:job_completions, :message_prefix)
      add_column :job_completions, :message_prefix, :string, limit: 50, after: :message
    end
    
    # Populate existing records
    execute <<-SQL
      UPDATE job_completions 
      SET message_prefix = LEFT(message, 50)
      WHERE message_prefix IS NULL
    SQL
    
    # Remove old unique index
    if index_exists?(:job_completions, [:source_id, :process_type, :job_type], name: 'index_job_completions_on_source_process_job')
      remove_index :job_completions, 
                   name: 'index_job_completions_on_source_process_job'
    end
    
    # Add non-unique index for query performance
    unless index_exists?(:job_completions, [:source_id, :process_type, :job_type], name: 'index_job_completions_on_source_process_job')
      add_index :job_completions, 
                [:source_id, :process_type, :job_type],
                name: 'index_job_completions_on_source_process_job'
    end
    
    # Add unique composite index including message_prefix for fast lookups
    unless index_exists?(:job_completions, [:source_id, :process_type, :job_type, :message_prefix], name: 'index_job_completions_on_source_process_job_message_prefix')
      add_index :job_completions,
                [:source_id, :process_type, :job_type, :message_prefix],
                unique: true,
                name: 'index_job_completions_on_source_process_job_message_prefix'
    end
  end

  def down
    # Remove unique composite index
    if index_exists?(:job_completions, [:source_id, :process_type, :job_type, :message_prefix], name: 'index_job_completions_on_source_process_job_message_prefix')
      remove_index :job_completions, name: 'index_job_completions_on_source_process_job_message_prefix'
    end
    
    # Remove non-unique index
    if index_exists?(:job_completions, [:source_id, :process_type, :job_type], name: 'index_job_completions_on_source_process_job')
      remove_index :job_completions, name: 'index_job_completions_on_source_process_job'
    end
    
    # Restore old unique index
    unless index_exists?(:job_completions, [:source_id, :process_type, :job_type], name: 'index_job_completions_on_source_process_job')
      add_index :job_completions,
                [:source_id, :process_type, :job_type],
                unique: true,
                name: 'index_job_completions_on_source_process_job'
    end
    
    # Remove message_prefix column
    if column_exists?(:job_completions, :message_prefix)
      remove_column :job_completions, :message_prefix
    end
  end
end
