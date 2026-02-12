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

ActiveRecord::Schema[8.1].define(version: 2026_02_12_210003) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "biology_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "lab_name"
    t.text "notes"
    t.date "test_date", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["test_date"], name: "index_biology_reports_on_test_date"
    t.index ["user_id", "test_date"], name: "index_biology_reports_on_user_id_and_test_date"
    t.index ["user_id"], name: "index_biology_reports_on_user_id"
  end

  create_table "biomarkers", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.decimal "ref_max", precision: 10, scale: 2, null: false
    t.decimal "ref_min", precision: 10, scale: 2, null: false
    t.string "unit", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_biomarkers_on_code", unique: true
    t.index ["name"], name: "index_biomarkers_on_name"
  end

  create_table "drugs", force: :cascade do |t|
    t.text "active_ingredients"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "rxcui"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_drugs_on_name"
    t.index ["rxcui"], name: "index_drugs_on_rxcui", unique: true
  end

  create_table "medication_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "logged_at"
    t.integer "medication_id", null: false
    t.integer "medication_schedule_id", null: false
    t.text "reason"
    t.date "scheduled_date", null: false
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.index ["medication_id"], name: "index_medication_logs_on_medication_id"
    t.index ["medication_schedule_id", "scheduled_date"], name: "index_medication_logs_on_schedule_and_date", unique: true
    t.index ["medication_schedule_id"], name: "index_medication_logs_on_medication_schedule_id"
    t.index ["scheduled_date"], name: "index_medication_logs_on_scheduled_date"
  end

  create_table "medication_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "days_of_week", null: false
    t.string "dosage_amount"
    t.text "instructions"
    t.integer "medication_id", null: false
    t.string "time_of_day", null: false
    t.datetime "updated_at", null: false
    t.index ["medication_id"], name: "index_medication_schedules_on_medication_id"
  end

  create_table "medications", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "dosage", null: false
    t.integer "drug_id", null: false
    t.string "form", null: false
    t.text "instructions"
    t.integer "prescription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_medications_on_active"
    t.index ["drug_id"], name: "index_medications_on_drug_id"
    t.index ["prescription_id"], name: "index_medications_on_prescription_id"
  end

  create_table "prescriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "doctor_name"
    t.text "notes"
    t.date "prescribed_date", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "prescribed_date"], name: "index_prescriptions_on_user_id_and_prescribed_date"
    t.index ["user_id"], name: "index_prescriptions_on_user_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "name", null: false
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "test_results", force: :cascade do |t|
    t.integer "biology_report_id", null: false
    t.integer "biomarker_id", null: false
    t.datetime "created_at", null: false
    t.boolean "out_of_range"
    t.decimal "ref_max", precision: 10, scale: 2
    t.decimal "ref_min", precision: 10, scale: 2
    t.string "unit", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 10, scale: 2, null: false
    t.index ["biology_report_id"], name: "index_test_results_on_biology_report_id"
    t.index ["biomarker_id"], name: "index_test_results_on_biomarker_id"
    t.index ["out_of_range"], name: "index_test_results_on_out_of_range"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "biology_reports", "users", on_delete: :cascade
  add_foreign_key "medication_logs", "medication_schedules"
  add_foreign_key "medication_logs", "medications"
  add_foreign_key "medication_schedules", "medications"
  add_foreign_key "medications", "drugs"
  add_foreign_key "medications", "prescriptions"
  add_foreign_key "prescriptions", "users"
  add_foreign_key "profiles", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "test_results", "biology_reports", on_delete: :cascade
  add_foreign_key "test_results", "biomarkers", on_delete: :restrict
end
