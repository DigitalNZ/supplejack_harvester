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

ActiveRecord::Schema[7.2].define(version: 2025_11_06_202433) do
  create_table "api_response_reports", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "automation_step_id", null: false
    t.string "status", default: "not_started", null: false
    t.integer "response_code"
    t.text "response_body"
    t.text "response_headers"
    t.datetime "executed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["automation_step_id"], name: "index_api_response_reports_on_automation_step_id"
  end

  create_table "automation_step_templates", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "automation_template_id", null: false
    t.bigint "pipeline_id"
    t.integer "position", default: 0, null: false
    t.text "harvest_definition_ids"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "step_type", default: "pipeline", null: false
    t.string "api_url"
    t.string "api_method"
    t.text "api_headers"
    t.text "api_body"
    t.index ["automation_template_id", "position"], name: "index_automation_step_templates_on_template_id_and_position"
    t.index ["automation_template_id"], name: "index_automation_step_templates_on_automation_template_id"
    t.index ["pipeline_id"], name: "index_automation_step_templates_on_pipeline_id"
  end

  create_table "automation_steps", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "automation_id", null: false
    t.bigint "pipeline_id"
    t.bigint "launched_by_id"
    t.integer "position", default: 0, null: false
    t.text "harvest_definition_ids"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "step_type", default: "pipeline", null: false
    t.string "api_url"
    t.string "api_method"
    t.text "api_headers"
    t.text "api_body"
    t.index ["automation_id", "position"], name: "index_automation_steps_on_automation_id_and_position", unique: true
    t.index ["automation_id"], name: "index_automation_steps_on_automation_id"
    t.index ["launched_by_id"], name: "index_automation_steps_on_launched_by_id"
    t.index ["pipeline_id"], name: "index_automation_steps_on_pipeline_id"
  end

  create_table "automation_templates", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "destination_id"
    t.bigint "last_edited_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "job_priority"
    t.index ["destination_id"], name: "index_automation_templates_on_destination_id"
    t.index ["last_edited_by_id"], name: "index_automation_templates_on_last_edited_by_id"
    t.index ["name"], name: "index_automation_templates_on_name", unique: true
  end

  create_table "automations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "destination_id", null: false
    t.bigint "automation_template_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "job_priority"
    t.index ["automation_template_id"], name: "index_automations_on_automation_template_id"
    t.index ["destination_id"], name: "index_automations_on_destination_id"
  end

  create_table "destinations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.string "api_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_destinations_on_name", unique: true
  end

  create_table "extraction_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "name"
    t.string "format"
    t.text "base_url"
    t.integer "throttle", default: 0, null: false
    t.string "pagination_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "kind", default: 0
    t.string "source_id"
    t.bigint "destination_id"
    t.bigint "pipeline_id"
    t.integer "page", default: 1
    t.string "total_selector"
    t.integer "per_page"
    t.boolean "paginated"
    t.bigint "last_edited_by_id"
    t.boolean "split", default: false, null: false
    t.string "split_selector"
    t.boolean "extract_text_from_file", default: false, null: false
    t.string "fragment_source_id"
    t.string "fragment_key"
    t.boolean "evaluate_javascript", default: false, null: false
    t.text "fields"
    t.boolean "include_sub_documents", default: true, null: false
    t.boolean "follow_redirects", default: true
    t.index ["destination_id"], name: "index_extraction_definitions_on_destination_id"
    t.index ["last_edited_by_id"], name: "index_extraction_definitions_on_last_edited_by_id"
    t.index ["name"], name: "index_extraction_definitions_on_name", unique: true, length: 255
    t.index ["pipeline_id"], name: "index_extraction_definitions_on_pipeline_id"
  end

  create_table "extraction_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "extraction_definition_id", null: false
    t.integer "kind", default: 0, null: false
    t.timestamp "start_time"
    t.timestamp "end_time"
    t.text "error_message"
    t.text "name"
    t.index ["extraction_definition_id"], name: "index_extraction_jobs_on_extraction_definition_id"
    t.index ["status"], name: "index_extraction_jobs_on_status"
  end

  create_table "field_schema_field_values", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "field_id", null: false
    t.bigint "schema_field_value_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["field_id"], name: "index_field_schema_field_values_on_field_id"
    t.index ["schema_field_value_id"], name: "index_field_schema_field_values_on_schema_field_value_id"
  end

  create_table "fields", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "block"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "transformation_definition_id", null: false
    t.integer "kind", default: 0
    t.bigint "schema_field_id"
    t.index ["schema_field_id"], name: "index_fields_on_schema_field_id"
    t.index ["transformation_definition_id"], name: "index_fields_on_transformation_definition_id"
  end

  create_table "harvest_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "name"
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
    t.bigint "extraction_job_id"
    t.text "name"
    t.string "key"
    t.string "target_job_id"
    t.bigint "pipeline_job_id"
    t.index ["extraction_job_id"], name: "index_harvest_jobs_on_extraction_job_id"
    t.index ["harvest_definition_id"], name: "index_harvest_jobs_on_harvest_definition_id"
    t.index ["key"], name: "index_harvest_jobs_on_key", unique: true
    t.index ["pipeline_job_id"], name: "index_harvest_jobs_on_pipeline_job_id"
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

  create_table "job_completion_summaries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "source_id", null: false
    t.string "source_name", null: false
    t.integer "completion_type", default: 0, null: false
    t.json "completion_entries", null: false
    t.integer "process_type", default: 0, null: false
    t.string "job_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "completion_count", default: 0, null: false
    t.index ["completion_type"], name: "index_job_completion_summaries_on_completion_type"
    t.index ["process_type"], name: "index_job_completion_summaries_on_process_type"
    t.index ["source_id", "process_type", "job_type"], name: "index_job_completion_summaries_on_source_process_job", unique: true
  end

  create_table "job_completions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_id", null: false
    t.string "source_name", null: false
    t.string "origin"
    t.string "job_type", null: false
    t.integer "process_type", null: false
    t.integer "completion_type", null: false
    t.text "message", null: false
    t.string "message_prefix", limit: 50
    t.json "stack_trace", null: false
    t.json "context", null: false
    t.json "details", null: false
    t.index ["source_id", "process_type", "job_type", "origin", "message_prefix"], name: "idx_jc_source_process_job_origin_msg", unique: true, length: { source_id: 100, job_type: 50, origin: 100 }
  end

  create_table "parameters", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "content"
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
    t.bigint "automation_step_id"
    t.string "job_priority"
    t.boolean "skip_previously_enriched", default: false
    t.index ["automation_step_id"], name: "index_pipeline_jobs_on_automation_step_id"
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
    t.bigint "pipeline_id"
    t.bigint "destination_id"
    t.boolean "delete_previous_records", default: false, null: false
    t.bigint "automation_template_id"
    t.string "job_priority"
    t.boolean "skip_previously_enriched", default: false
    t.index ["automation_template_id"], name: "index_schedules_on_automation_template_id"
    t.index ["destination_id"], name: "index_schedules_on_destination_id"
    t.index ["name"], name: "index_schedules_on_name", unique: true
    t.index ["pipeline_id"], name: "index_schedules_on_pipeline_id"
  end

  create_table "schema_field_values", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "schema_field_id", null: false
    t.index ["schema_field_id"], name: "index_schema_field_values_on_schema_field_id"
  end

  create_table "schema_fields", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "schema_id", null: false
    t.integer "kind", default: 0
    t.index ["schema_id"], name: "index_schema_fields_on_schema_id"
  end

  create_table "schemas", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "last_edited_by_id"
    t.index ["last_edited_by_id"], name: "index_schemas_on_last_edited_by_id"
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
    t.text "name"
    t.string "record_selector"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "extraction_job_id", null: false
    t.integer "kind", default: 0
    t.bigint "pipeline_id"
    t.bigint "last_edited_by_id"
    t.index ["extraction_job_id"], name: "index_transformation_definitions_on_extraction_job_id"
    t.index ["last_edited_by_id"], name: "index_transformation_definitions_on_last_edited_by_id"
    t.index ["name"], name: "index_transformation_definitions_on_name", unique: true, length: 255
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
    t.string "api_key"
    t.index ["api_key"], name: "index_users_on_api_key", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "api_response_reports", "automation_steps"
  add_foreign_key "automation_step_templates", "automation_templates"
  add_foreign_key "automation_step_templates", "pipelines"
  add_foreign_key "automation_steps", "automations"
  add_foreign_key "automation_steps", "pipelines"
  add_foreign_key "automation_steps", "users", column: "launched_by_id"
  add_foreign_key "automation_templates", "destinations"
  add_foreign_key "automation_templates", "users", column: "last_edited_by_id"
  add_foreign_key "automations", "automation_templates"
  add_foreign_key "automations", "destinations"
  add_foreign_key "extraction_definitions", "users", column: "last_edited_by_id"
  add_foreign_key "field_schema_field_values", "fields"
  add_foreign_key "field_schema_field_values", "schema_field_values"
  add_foreign_key "pipeline_jobs", "automation_steps"
  add_foreign_key "pipelines", "users", column: "last_edited_by_id"
  add_foreign_key "schemas", "users", column: "last_edited_by_id"
  add_foreign_key "transformation_definitions", "users", column: "last_edited_by_id"
end
