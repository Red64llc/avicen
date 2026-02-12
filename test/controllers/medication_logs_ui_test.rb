require "test_helper"

class MedicationLogsUiTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  # --- Quick-action buttons on pending entries ---

  test "schedule entry shows taken and skipped buttons when status is pending" do
    # Feb 9 2026 is a Monday - morning_daily schedule should be pending
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # Should have the medication-log Stimulus controller
    assert_select "[data-controller='medication-log']"

    # Should have Taken button
    assert_select "button", text: /Taken/i
    # Should have Skipped button
    assert_select "button", text: /Skipped/i
  end

  test "schedule entry shows undo button when status is taken" do
    # Feb 10 2026 is a Tuesday - taken_log exists for morning_daily
    get schedule_path, params: { date: "2026-02-10" }
    assert_response :success

    # Should have an Undo button for the taken entry
    assert_select "button", text: /Undo/i
  end

  test "schedule entry shows undo button when status is skipped" do
    # Feb 10 2026 is a Tuesday - skipped_log exists for evening_weekdays
    get schedule_path, params: { date: "2026-02-10" }
    assert_response :success

    # Should have Undo buttons (at least one for the skipped entry)
    assert_select "button", text: /Undo/i
  end

  test "schedule entry has unique turbo stream target DOM ID including date" do
    schedule = medication_schedules(:morning_daily)
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # Each entry must have a unique DOM ID with schedule_id AND date for Turbo Stream targeting
    # Format: schedule_entry_{schedule_id}_{date}
    assert_select "#schedule_entry_#{schedule.id}_2026-02-09"
  end

  test "different dates produce different DOM IDs for same schedule" do
    schedule = medication_schedules(:morning_daily)

    # Monday
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success
    assert_select "#schedule_entry_#{schedule.id}_2026-02-09"

    # Tuesday
    get schedule_path, params: { date: "2026-02-10" }
    assert_response :success
    assert_select "#schedule_entry_#{schedule.id}_2026-02-10"
  end

  test "pending entry forms submit as turbo stream to medication_logs_path" do
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # Should have forms that POST to medication_logs_path
    assert_select "form[action=?]", medication_logs_path
  end

  test "taken entry has undo form that deletes the medication log" do
    taken_log = medication_logs(:taken_log)
    # Feb 10 2026 - taken_log exists
    get schedule_path, params: { date: "2026-02-10" }
    assert_response :success

    # Should have a form to DELETE the medication log (undo)
    assert_select "form[action=?]", medication_log_path(taken_log)
  end

  # --- Skip reason field ---

  test "pending entry includes a reason text field for skipping" do
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # Should have a reason input field (shown when skipping)
    assert_select "[data-medication-log-target='reasonField']"
  end

  # --- Stimulus controller attributes ---

  test "schedule entry has medication-log controller with proper data attributes" do
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # Should have the Stimulus controller wrapper
    assert_select "[data-controller='medication-log']"
  end

  # --- Turbo Stream create replaces entry with buttons ---

  test "create turbo stream response includes undo button" do
    schedule = medication_schedules(:morning_daily)
    medication = medications(:aspirin_morning)

    post medication_logs_path, params: {
      medication_log: {
        medication_id: medication.id,
        medication_schedule_id: schedule.id,
        scheduled_date: "2026-02-11",
        status: "taken"
      }
    }, as: :turbo_stream

    assert_response :success
    # Response should contain an undo button
    assert_match(/Undo/i, response.body)
  end

  test "create turbo stream targets the date-inclusive DOM ID" do
    schedule = medication_schedules(:morning_daily)
    medication = medications(:aspirin_morning)

    post medication_logs_path, params: {
      medication_log: {
        medication_id: medication.id,
        medication_schedule_id: schedule.id,
        scheduled_date: "2026-02-11",
        status: "taken"
      }
    }, as: :turbo_stream

    assert_response :success
    # Turbo Stream should target the date-inclusive DOM ID
    assert_match "schedule_entry_#{schedule.id}_2026-02-11", response.body
  end

  test "destroy turbo stream response includes taken and skipped buttons" do
    log = MedicationLog.create!(
      medication: medications(:aspirin_morning),
      medication_schedule: medication_schedules(:morning_daily),
      scheduled_date: "2026-02-11",
      status: :taken,
      logged_at: Time.current
    )

    delete medication_log_path(log), as: :turbo_stream

    assert_response :success
    # Response should contain taken/skipped buttons (back to pending)
    assert_match(/Taken/i, response.body)
    assert_match(/Skipped/i, response.body)
  end

  test "destroy turbo stream targets the date-inclusive DOM ID" do
    schedule = medication_schedules(:morning_daily)
    log = MedicationLog.create!(
      medication: medications(:aspirin_morning),
      medication_schedule: schedule,
      scheduled_date: "2026-02-11",
      status: :taken,
      logged_at: Time.current
    )

    delete medication_log_path(log), as: :turbo_stream

    assert_response :success
    # Turbo Stream should target the date-inclusive DOM ID
    assert_match "schedule_entry_#{schedule.id}_2026-02-11", response.body
  end
end
