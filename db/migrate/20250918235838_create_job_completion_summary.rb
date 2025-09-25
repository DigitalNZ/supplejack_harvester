class CreateJobCompletionSummary < ActiveRecord::Migration[7.2]
  def change
    # Only create table if it doesn't exist
    unless table_exists?(:job_completion_summaries)
      create_table :job_completion_summaries do |t|
        t.string :source_id, null: false
        t.string :source_name, null: false
        t.integer :completion_type, null: false, default: 0 # 0 = error, 1 = stop_condition
        t.json :completion_entries, null: false
        t.integer :completion_count, default: 0
        t.datetime :last_occurred_at
        t.integer :process_type, null: false, default: 0 # 0 = extraction, 1 = transformation, 2 = loading, 3 = deletion
        t.string :job_type, null: false
        t.timestamps
      end
      
      add_index :job_completion_summaries, [:source_id, :process_type, :job_type], 
                unique: true, name: 'index_job_completion_summaries_on_source_process_job'
      add_index :job_completion_summaries, :completion_type
      add_index :job_completion_summaries, :process_type
      add_index :job_completion_summaries, :last_occurred_at
    else
      puts "Table job_completion_summaries already exists, skipping creation"
    end
  end
end
