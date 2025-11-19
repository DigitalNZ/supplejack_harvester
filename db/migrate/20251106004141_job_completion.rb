class JobCompletion < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:job_completions)
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
        t.json :details, null: false
        t.timestamps
      end

      add_index :job_completions, 
                [:source_id, :process_type, :job_type],
                name: 'index_job_completions_on_source_process_job'

      add_index :job_completions,
                [:source_id, :process_type, :job_type, :origin, :message_prefix],
                unique: true,
                name: 'index_job_completions_on_source_process_origin_message',
                length: { source_id: 100, job_type: 50, origin: 100, message_prefix: 50 }
    end
  end
end
