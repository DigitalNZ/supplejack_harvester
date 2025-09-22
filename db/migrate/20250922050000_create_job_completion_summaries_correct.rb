class CreateJobCompletionSummariesCorrect < ActiveRecord::Migration[7.2]
  def up
    create_table :job_completion_summaries do |t|
      t.string :extraction_id, null: false
      t.string :extraction_name, null: false
      t.string :completion_type, null: false
      t.json :completion_details, null: false
      t.integer :completion_count, default: 0
      t.datetime :last_occurred_at
      t.timestamps
    end
    
    add_index :job_completion_summaries, :extraction_id, unique: true
    add_index :job_completion_summaries, :completion_type
    add_index :job_completion_summaries, :last_occurred_at
  end

  def down
    drop_table :job_completion_summaries
  end
end
