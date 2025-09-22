class CreateJobCompletionSummary < ActiveRecord::Migration[7.2]
  def change
    # Only create table if it doesn't exist
    unless table_exists?(:job_completion_summaries)
      create_table :job_completion_summaries do |t|
        t.string :extraction_id, null: false
        t.string :extraction_name, null: false
        t.integer :completion_type, null: false, default: 0 # 0 = error, 1 = stop_condition
        t.json :completion_details, null: false
        t.integer :completion_count, default: 0
        t.datetime :last_occurred_at
        t.timestamps
      end
      
      add_index :job_completion_summaries, :extraction_id, unique: true
      add_index :job_completion_summaries, :completion_type
      add_index :job_completion_summaries, :last_occurred_at
    else
      puts "Table job_completion_summaries already exists, skipping creation"
    end
  end
end
