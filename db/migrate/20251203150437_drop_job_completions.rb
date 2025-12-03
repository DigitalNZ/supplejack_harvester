class DropJobCompletions < ActiveRecord::Migration[7.2]
  def up
    # Remove foreign key first (as defined in schema.rb)
    if foreign_key_exists?(:job_completions, :job_completion_summaries)
      remove_foreign_key :job_completions, :job_completion_summaries
    end

    drop_table :job_completions
  end

  def down
    create_table "job_completions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
      t.string   "origin"
      t.integer  "process_type", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.bigint   "job_completion_summary_id", null: false
      t.bigint   "job_id", null: false
      t.string   "stop_condition_type", null: false
      t.string   "stop_condition_name", null: false
      t.text     "stop_condition_content", null: false

      t.index ["job_completion_summary_id"], name: "index_job_completions_on_job_completion_summary_id"
      t.index ["job_id", "origin", "stop_condition_name"], name: "index_job_completions_on_job_origin_stop_condition", unique: true
      t.index ["job_id"], name: "index_job_completions_on_job_id"
      t.index ["process_type"], name: "index_job_completions_on_source_process_job"
    end

    add_foreign_key "job_completions", "job_completion_summaries", on_delete: :cascade
  end
end
