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

ActiveRecord::Schema[7.0].define(version: 2023_07_13_015208) do
  create_table "content_sources", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "destinations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.string "api_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "extraction_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "name"
    t.string "format"
    t.string "base_url"
    t.integer "throttle", default: 0, null: false
    t.string "pagination_type"
    t.string "page_parameter"
    t.string "per_page_parameter"
    t.integer "page"
    t.integer "per_page"
    t.string "total_selector"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "content_source_id"
    t.bigint "original_extraction_definition_id"
    t.integer "kind", default: 0
    t.string "source_id"
    t.string "enrichment_url"
    t.bigint "destination_id"
    t.string "job_id"
    t.string "next_token_path"
    t.string "token_parameter"
    t.string "token_value"
    t.string "initial_params"
    t.bigint "pipeline_id"
    t.index ["content_source_id"], name: "index_extraction_definitions_on_content_source_id"
    t.index ["destination_id"], name: "index_extraction_definitions_on_destination_id"
    t.index ["original_extraction_definition_id"], name: "index_eds_on_original_ed_id"
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
  end

  create_table "fields", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "block"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "transformation_definition_id", null: false
    t.index ["transformation_definition_id"], name: "index_fields_on_transformation_definition_id"
  end

  create_table "harvest_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "content_source_id"
    t.bigint "extraction_definition_id"
    t.bigint "transformation_definition_id"
    t.string "source_id"
    t.integer "kind", default: 0
    t.integer "priority", default: 0
    t.boolean "required_for_active_record", default: false
    t.bigint "pipeline_id"
    t.index ["content_source_id"], name: "index_harvest_definitions_on_content_source_id"
    t.index ["extraction_definition_id"], name: "index_harvest_definitions_on_extraction_definition_id"
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
    t.bigint "destination_id"
    t.index ["destination_id"], name: "index_harvest_jobs_on_destination_id"
    t.index ["extraction_job_id"], name: "index_harvest_jobs_on_extraction_job_id"
    t.index ["harvest_definition_id"], name: "index_harvest_jobs_on_harvest_definition_id"
  end

  create_table "headers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "extraction_definition_id", null: false
    t.index ["extraction_definition_id"], name: "index_headers_on_extraction_definition_id"
  end

  create_table "load_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "status", default: 0
    t.integer "kind", default: 0, null: false
    t.timestamp "start_time"
    t.timestamp "end_time"
    t.integer "records_loaded", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "harvest_job_id"
    t.integer "page", default: 1, null: false
    t.text "name"
    t.string "api_record_id"
    t.index ["harvest_job_id"], name: "index_load_jobs_on_harvest_job_id"
  end

  create_table "pipelines", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "transformation_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "name"
    t.string "record_selector", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "content_source_id"
    t.bigint "extraction_job_id", null: false
    t.bigint "original_transformation_definition_id"
    t.integer "kind", default: 0
    t.bigint "pipeline_id"
    t.index ["content_source_id"], name: "index_transformation_definitions_on_content_source_id"
    t.index ["extraction_job_id"], name: "index_transformation_definitions_on_extraction_job_id"
    t.index ["original_transformation_definition_id"], name: "index_tds_on_original_td_id"
    t.index ["pipeline_id"], name: "index_transformation_definitions_on_pipeline_id"
  end

  create_table "transformation_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "status", default: 0
    t.integer "kind", default: 0, null: false
    t.integer "page"
    t.timestamp "start_time"
    t.timestamp "end_time"
    t.text "error_message"
    t.integer "records_transformed", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "transformation_definition_id"
    t.bigint "harvest_job_id"
    t.bigint "extraction_job_id"
    t.text "name"
    t.string "api_record_id"
    t.index ["extraction_job_id"], name: "index_transformation_jobs_on_extraction_job_id"
    t.index ["harvest_job_id"], name: "index_transformation_jobs_on_harvest_job_id"
    t.index ["transformation_definition_id"], name: "index_transformation_jobs_on_transformation_definition_id"
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

end
