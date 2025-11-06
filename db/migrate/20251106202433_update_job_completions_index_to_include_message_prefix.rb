class UpdateJobCompletionsIndexToIncludeMessagePrefix < ActiveRecord::Migration[7.2]
  def change
    # Remove old index that doesn't include message_prefix
    remove_index :job_completions,
                 name: 'index_job_completions_on_source_process_job_origin',
                 if_exists: true
    
    # Add unique index including message_prefix for fast lookups and duplicate prevention
    # Specify prefix lengths for string columns to avoid MySQL key length limit
    add_index :job_completions,
              [:source_id, :process_type, :job_type, :origin, :message_prefix],
              unique: true,
              name: 'idx_jc_source_process_job_origin_msg',
              length: { source_id: 100, job_type: 50, origin: 100, message_prefix: 50 }
  end
end
