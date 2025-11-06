class AddOriginToJobCompletions < ActiveRecord::Migration[7.2]
  def change
    add_column :job_completions, :origin, :string, after: :source_name
    
    # Add index for faster lookups
    add_index :job_completions,
              [:source_id, :process_type, :job_type, :origin],
              name: 'index_job_completions_on_source_process_job_origin'
  end
end
