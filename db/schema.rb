# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_08_05_030116) do
  create_table "destinations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.string "api_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_destinations_on_name", unique: true
  end

  create_table "extraction_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.string "format"
    t.string "base_url"
    t.integer "throttle", default: 0, null: false
    t.string "pagination_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "kind", default: 0
    t.bigint "destination_id"
    t.integer "page", default: 1
    t.boolean "paginated"
    t.bigint "last_edited_by_id"
    t.bigint "pipeline_id"
    t.string "source_id"
    t.integer "per_page"
    t.string "total_selector"
    t.boolean "split", default: false, null: false
    t.string "split_selector"
    t.boolean "extract_text_from_file", default: false, null: false
    t.string "fragment_source_id"
    t.string "fragment_key"
    t.index ["destination_id"], name: "index_extraction_definitions_on_destination_id"
    t.index ["last_edited_by_id"], name: "index_extraction_definitions_on_last_edited_by_id"
    t.index ["name"], name: "index_extraction_definitions_on_name", unique: true
    t.index ["pipeline_id"], name: "index_extraction_definitions_on_pipeline_id"
  end

  create_table "extraction_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "extraction_definition_id", null: false
    t.timestamp "start_time"
    t.timestamp "end_time"
    t.text "error_message"
    t.text "name"
    t.integer "kind"
    t.index ["extraction_definition_id"], name: "index_extraction_jobs_on_extraction_definition_id"
    t.index ["status"], name: "index_extraction_jobs_on_status"
  end

  create_table "fields", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "block"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "transformation_definition_id", null: false
    t.integer "kind", default: 0
    t.index ["transformation_definition_id"], name: "index_fields_on_transformation_definition_id"
  end

  create_table "harvest_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "extraction_definition_id"
    t.bigint "transformation_definition_id"
    t.string "source_id"
    t.integer "kind", default: 0
    t.integer "priority", default: 0
    t.boolean "required_for_active_record", default: false
    t.bigint "pipeline_id"
    t.bigint "harvest_report_id"
    t.index ["extraction_definition_id"], name: "index_harvest_definitions_on_extraction_definition_id"
    t.index ["harvest_report_id"], name: "index_harvest_definitions_on_harvest_report_id"
    t.index ["pipeline_id"], name: "index_harvest_definitions_on_pipeline_id"
    t.index ["transformation_definition_id"], name: "index_harvest_definitions_on_transformation_definition_id"
  end

  create_table "harvest_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "status", default: 0
    t.integer "kind", default: 0, null: false
    t.timestamp "start_time"
    t.timestamp "end_time"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "harvest_definition_id"
    t.text "name"
    t.string "key"
    t.string "target_job_id"
    t.integer "pipeline_job_id"
    t.integer "extraction_job_id"
    t.index ["harvest_definition_id"], name: "index_harvest_jobs_on_harvest_definition_id"
    t.index ["key"], name: "index_harvest_jobs_on_key", unique: true
    t.index ["status"], name: "index_harvest_jobs_on_status"
  end

  create_table "harvest_reports", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "extraction_status", default: 0
    t.timestamp "extraction_start_time"
    t.timestamp "extraction_end_time"
    t.integer "transformation_status", default: 0
    t.timestamp "transformation_start_time"
    t.timestamp "transformation_end_time"
    t.integer "load_status", default: 0
    t.timestamp "load_start_time"
    t.timestamp "load_end_time"
    t.integer "pages_extracted", default: 0, null: false
    t.integer "records_transformed", default: 0, null: false
    t.integer "records_loaded", default: 0, null: false
    t.integer "records_rejected", default: 0, null: false
    t.integer "records_deleted", default: 0, null: false
    t.text "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "pipeline_job_id"
    t.bigint "harvest_job_id"
    t.integer "transformation_workers_queued", default: 0
    t.integer "transformation_workers_completed", default: 0
    t.integer "load_workers_queued", default: 0
    t.integer "load_workers_completed", default: 0
    t.integer "delete_workers_queued", default: 0
    t.integer "delete_workers_completed", default: 0
    t.integer "delete_status", default: 0
    t.timestamp "delete_start_time"
    t.timestamp "delete_end_time"
    t.integer "kind", default: 0
    t.timestamp "extraction_updated_time"
    t.timestamp "transformation_updated_time"
    t.timestamp "load_updated_time"
    t.timestamp "delete_updated_time"
    t.string "definition_name"
    t.index ["harvest_job_id"], name: "index_harvest_reports_on_harvest_job_id"
    t.index ["pipeline_job_id"], name: "index_harvest_reports_on_pipeline_job_id"
  end

  create_table "parameters", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.string "content"
    t.integer "kind", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "request_id", null: false
    t.integer "content_type", default: 0
    t.index ["request_id"], name: "index_parameters_on_request_id"
  end

  create_table "pipeline_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.timestamp "start_time"
    t.timestamp "end_time"
    t.text "name"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "pipeline_id"
    t.string "key"
    t.string "harvest_definitions_to_run"
    t.bigint "destination_id"
    t.bigint "extraction_job_id"
    t.integer "page_type", default: 0
    t.integer "pages"
    t.bigint "schedule_id"
    t.bigint "launched_by_id"
    t.boolean "delete_previous_records", default: false, null: false
    t.boolean "run_enrichment_concurrently", default: false, null: false
    t.index ["destination_id"], name: "index_pipeline_jobs_on_destination_id"
    t.index ["extraction_job_id"], name: "index_pipeline_jobs_on_extraction_job_id"
    t.index ["key"], name: "index_pipeline_jobs_on_key", unique: true
    t.index ["launched_by_id"], name: "index_pipeline_jobs_on_launched_by_id"
    t.index ["pipeline_id"], name: "index_pipeline_jobs_on_pipeline_id"
    t.index ["schedule_id"], name: "index_pipeline_jobs_on_schedule_id"
  end

  create_table "pipelines", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "last_edited_by_id"
    t.index ["last_edited_by_id"], name: "index_pipelines_on_last_edited_by_id"
    t.index ["name"], name: "index_pipelines_on_name", unique: true
  end

  create_table "requests", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "extraction_definition_id", null: false
    t.integer "http_method", default: 0
    t.index ["extraction_definition_id"], name: "index_requests_on_extraction_definition_id"
  end

  create_table "schedules", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.integer "frequency", default: 0
    t.string "time"
    t.integer "day"
    t.string "harvest_definitions_to_run"
    t.integer "day_of_the_month"
    t.integer "bi_monthly_day_one"
    t.integer "bi_monthly_day_two"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "pipeline_id", null: false
    t.bigint "destination_id"
    t.boolean "delete_previous_records", default: false, null: false
    t.index ["destination_id"], name: "index_schedules_on_destination_id"
    t.index ["name"], name: "index_schedules_on_name", unique: true
    t.index ["pipeline_id"], name: "index_schedules_on_pipeline_id"
  end

  create_table "stop_conditions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "extraction_definition_id"
    t.index ["extraction_definition_id"], name: "index_stop_conditions_on_extraction_definition_id"
  end

  create_table "transformation_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.string "record_selector"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "extraction_job_id", null: false
    t.integer "kind", default: 0
    t.bigint "pipeline_id"
    t.bigint "last_edited_by_id"
    t.index ["extraction_job_id"], name: "index_transformation_definitions_on_extraction_job_id"
    t.index ["last_edited_by_id"], name: "index_transformation_definitions_on_last_edited_by_id"
    t.index ["name"], name: "index_transformation_definitions_on_name", unique: true
    t.index ["pipeline_id"], name: "index_transformation_definitions_on_pipeline_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", default: "", null: false
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.integer "role", default: 0, null: false
    t.string "otp_secret"
    t.integer "consumed_timestep"
    t.boolean "otp_required_for_login"
    t.boolean "two_factor_setup", default: false, null: false
    t.boolean "enforce_two_factor", default: true, null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.string "unlock_token"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "extraction_definitions", "users", column: "last_edited_by_id"
  add_foreign_key "pipelines", "users", column: "last_edited_by_id"
  add_foreign_key "transformation_definitions", "users", column: "last_edited_by_id"
end
