require "test_helper"

class MedicationLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @medication = medications(:aspirin_morning)
    @schedule = medication_schedules(:morning_daily)
    @ibuprofen_medication = medications(:ibuprofen_evening)
    @evening_schedule = medication_schedules(:evening_weekdays)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "create requires authentication" do
    sign_out
    post medication_logs_path, params: {
      medication_log: {
        medication_id: @medication.id,
        medication_schedule_id: @schedule.id,
        scheduled_date: "2026-02-11",
        status: "taken"
      }
    }
    assert_redirected_to new_session_path
  end

  test "destroy requires authentication" do
    log = medication_logs(:taken_log)
    sign_out
    delete medication_log_path(log)
    assert_redirected_to new_session_path
  end

  # --- Create: Taken ---

  test "create taken log creates a new medication log record" do
    assert_difference "MedicationLog.count", 1 do
      post medication_logs_path, params: {
        medication_log: {
          medication_id: @medication.id,
          medication_schedule_id: @schedule.id,
          scheduled_date: "2026-02-11",
          status: "taken"
        }
      }, as: :turbo_stream
    end

    log = MedicationLog.last
    assert_equal @medication.id, log.medication_id
    assert_equal @schedule.id, log.medication_schedule_id
    assert_equal Date.parse("2026-02-11"), log.scheduled_date
    assert log.taken?
    assert_not_nil log.logged_at
  end

  test "create taken log sets logged_at automatically to current time" do
    freeze_time do
      post medication_logs_path, params: {
        medication_log: {
          medication_id: @medication.id,
          medication_schedule_id: @schedule.id,
          scheduled_date: "2026-02-11",
          status: "taken"
        }
      }, as: :turbo_stream

      log = MedicationLog.last
      assert_equal Time.current.to_i, log.logged_at.to_i
    end
  end

  # --- Create: Skipped with reason ---

  test "create skipped log with reason creates a new medication log record" do
    assert_difference "MedicationLog.count", 1 do
      post medication_logs_path, params: {
        medication_log: {
          medication_id: @ibuprofen_medication.id,
          medication_schedule_id: @evening_schedule.id,
          scheduled_date: "2026-02-11",
          status: "skipped",
          reason: "Felt nauseous"
        }
      }, as: :turbo_stream
    end

    log = MedicationLog.last
    assert log.skipped?
    assert_equal "Felt nauseous", log.reason
    assert_not_nil log.logged_at
  end

  # --- Idempotent Upsert ---

  test "create with existing log for same schedule and date updates the existing record" do
    # Create an initial log
    existing_log = MedicationLog.create!(
      medication: @medication,
      medication_schedule: @schedule,
      scheduled_date: "2026-02-11",
      status: :taken,
      logged_at: 1.hour.ago
    )

    assert_no_difference "MedicationLog.count" do
      post medication_logs_path, params: {
        medication_log: {
          medication_id: @medication.id,
          medication_schedule_id: @schedule.id,
          scheduled_date: "2026-02-11",
          status: "skipped",
          reason: "Changed my mind"
        }
      }, as: :turbo_stream
    end

    existing_log.reload
    assert existing_log.skipped?
    assert_equal "Changed my mind", existing_log.reason
  end

  # --- Turbo Stream Response Format ---

  test "create responds with Turbo Stream format" do
    post medication_logs_path, params: {
      medication_log: {
        medication_id: @medication.id,
        medication_schedule_id: @schedule.id,
        scheduled_date: "2026-02-11",
        status: "taken"
      }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end

  test "create turbo stream replaces the schedule entry target" do
    post medication_logs_path, params: {
      medication_log: {
        medication_id: @medication.id,
        medication_schedule_id: @schedule.id,
        scheduled_date: "2026-02-11",
        status: "taken"
      }
    }, as: :turbo_stream

    assert_response :success
    # Should contain a turbo-stream replace targeting the schedule entry with date-inclusive DOM ID
    assert_match "schedule_entry_#{@schedule.id}_2026-02-11", response.body
    assert_match "turbo-stream", response.body
  end

  # --- Create: Validation Error ---

  test "create with invalid params returns unprocessable entity" do
    assert_no_difference "MedicationLog.count" do
      post medication_logs_path, params: {
        medication_log: {
          medication_id: @medication.id,
          medication_schedule_id: @schedule.id,
          scheduled_date: "",
          status: "taken"
        }
      }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  # --- Destroy (Undo) ---

  test "destroy deletes the medication log record" do
    log = MedicationLog.create!(
      medication: @medication,
      medication_schedule: @schedule,
      scheduled_date: "2026-02-11",
      status: :taken,
      logged_at: Time.current
    )

    assert_difference "MedicationLog.count", -1 do
      delete medication_log_path(log), as: :turbo_stream
    end
  end

  test "destroy responds with Turbo Stream replacing entry as pending" do
    log = MedicationLog.create!(
      medication: @medication,
      medication_schedule: @schedule,
      scheduled_date: "2026-02-11",
      status: :taken,
      logged_at: Time.current
    )

    delete medication_log_path(log), as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    # Should target the schedule entry for replacement with date-inclusive DOM ID
    assert_match "schedule_entry_#{@schedule.id}_2026-02-11", response.body
    assert_match "turbo-stream", response.body
  end

  test "destroy returns not found for non-existent log" do
    delete medication_log_path(id: 999999), as: :turbo_stream
    assert_response :not_found
  end

  # --- User Scoping ---

  test "create scopes through current user prescriptions" do
    # other_user_prescription belongs to user :two
    other_prescription = prescriptions(:other_user_prescription)
    other_med = Medication.create!(
      prescription: other_prescription,
      drug: drugs(:aspirin),
      dosage: "50mg",
      form: "tablet"
    )
    other_schedule = MedicationSchedule.create!(
      medication: other_med,
      time_of_day: "09:00",
      days_of_week: [ 1, 2, 3, 4, 5 ]
    )

    assert_no_difference "MedicationLog.count" do
      post medication_logs_path, params: {
        medication_log: {
          medication_id: other_med.id,
          medication_schedule_id: other_schedule.id,
          scheduled_date: "2026-02-11",
          status: "taken"
        }
      }, as: :turbo_stream
    end

    assert_response :not_found
  end

  test "destroy scopes through current user prescriptions" do
    other_prescription = prescriptions(:other_user_prescription)
    other_med = Medication.create!(
      prescription: other_prescription,
      drug: drugs(:aspirin),
      dosage: "50mg",
      form: "tablet"
    )
    other_schedule = MedicationSchedule.create!(
      medication: other_med,
      time_of_day: "09:00",
      days_of_week: [ 1, 2, 3, 4, 5 ]
    )
    other_log = MedicationLog.create!(
      medication: other_med,
      medication_schedule: other_schedule,
      scheduled_date: "2026-02-11",
      status: :taken,
      logged_at: Time.current
    )

    assert_no_difference "MedicationLog.count" do
      delete medication_log_path(other_log), as: :turbo_stream
    end

    assert_response :not_found
  end

  # --- Strong Parameters ---

  test "create does not allow setting logged_at through params" do
    custom_time = 1.year.ago
    post medication_logs_path, params: {
      medication_log: {
        medication_id: @medication.id,
        medication_schedule_id: @schedule.id,
        scheduled_date: "2026-02-11",
        status: "taken",
        logged_at: custom_time
      }
    }, as: :turbo_stream

    log = MedicationLog.last
    assert_not_equal custom_time.to_i, log.logged_at.to_i
  end
end
