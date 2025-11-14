class CreateJobErrors < ActiveRecord::Migration[7.2]
  def change
    create_table :job_errors, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.bigint :job_id, null: false
      t.text :message, null: false
      t.json :stack_trace, null: false
      t.integer :process_type, null: false
      t.string :origin, null: false
      t.bigint :job_completion_summary_id, null: false
      
      t.timestamps
    end
    
    add_index :job_errors, :job_completion_summary_id
    add_index :job_errors, 
              [:job_id, :origin, :message],
              unique: true,
              name: 'index_job_errors_on_job_origin_message',
              length: { message: 255 }
    add_index :job_errors, :job_id
    add_index :job_errors, :process_type
    
    add_foreign_key :job_errors, :job_completion_summaries
  end
end