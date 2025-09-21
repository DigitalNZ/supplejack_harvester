class CreateJobCompletionSummary < ActiveRecord::Migration[7.2]
  def change
    # Only create table if it doesn't exist
    unless table_exists?(:job_completion_summaries)
      create_table :job_completion_summaries do |t|
        t.string :extraction_id, null: false
        t.string :extraction_name, null: false
        t.string :error_type, null: false
        t.json :error_details, null: false
        t.integer :error_count, default: 0
        t.datetime :first_error_at
        t.datetime :last_error_at
        t.timestamps
      end
      
      add_index :job_completion_summaries, :extraction_id, unique: true
      add_index :job_completion_summaries, :error_type
      add_index :job_completion_summaries, :first_error_at
      add_index :job_completion_summaries, :last_error_at
    else
      puts "Table job_completion_summaries already exists, skipping creation"
    end
  end
end
