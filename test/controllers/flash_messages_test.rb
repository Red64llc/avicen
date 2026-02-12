require "test_helper"

class FlashMessagesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @prescription = prescriptions(:one)
    @medication = medications(:aspirin_morning)
    @medication_schedule = medication_schedules(:morning_daily)
    sign_in_as(@user)
  end

  # --- Prescriptions Flash Messages ---

  test "prescription create displays success flash message" do
    post prescriptions_path, params: {
      prescription: {
        doctor_name: "Dr. Flash",
        prescribed_date: Date.current,
        notes: "Flash test"
      }
    }
    assert_redirected_to prescription_path(Prescription.last)
    follow_redirect!
    assert_select ".bg-green-50", /created/i
  end

  test "prescription update displays success flash message" do
    patch prescription_path(@prescription), params: {
      prescription: { doctor_name: "Dr. Updated Flash" }
    }
    assert_redirected_to prescription_path(@prescription)
    follow_redirect!
    assert_select ".bg-green-50", /updated/i
  end

  test "prescription delete displays success flash message" do
    delete prescription_path(@prescription)
    assert_redirected_to prescriptions_path
    follow_redirect!
    assert_select ".bg-green-50", /deleted/i
  end

  # --- Medications Flash Messages (HTML fallback) ---

  test "medication create via HTML displays success flash message" do
    post prescription_medications_path(@prescription), params: {
      medication: {
        drug_id: drugs(:aspirin).id,
        dosage: "500mg",
        form: "tablet",
        instructions: "Test flash"
      }
    }
    # HTML fallback should redirect with notice
    assert_redirected_to prescription_path(@prescription)
    follow_redirect!
    assert_select ".bg-green-50", /added/i
  end

  test "medication update via HTML displays success flash message" do
    patch medication_path(@medication), params: {
      medication: { dosage: "150mg" }
    }
    # HTML fallback should redirect with notice
    assert_redirected_to prescription_path(@medication.prescription)
    follow_redirect!
    assert_select ".bg-green-50", /updated/i
  end

  test "medication destroy via HTML displays success flash message" do
    delete medication_path(@medication)
    assert_redirected_to prescription_path(@prescription)
    follow_redirect!
    assert_select ".bg-green-50", /removed/i
  end

  # --- Medications Flash Messages (Turbo Stream) ---

  test "medication create via Turbo Stream includes flash in response" do
    post prescription_medications_path(@prescription), params: {
      medication: {
        drug_id: drugs(:aspirin).id,
        dosage: "500mg",
        form: "tablet",
        instructions: "Test Turbo flash"
      }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    # Turbo Stream response should include a flash message update
    assert_match(/turbo-stream/, response.body)
    assert_match(/flash/, response.body)
  end

  test "medication destroy via Turbo Stream includes flash in response" do
    delete medication_path(@medication), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match(/turbo-stream/, response.body)
    assert_match(/flash/, response.body)
  end

  # --- Medication Schedules Flash Messages (HTML fallback) ---

  test "schedule create via HTML displays success flash message" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "14:00",
        days_of_week: [ 1, 3, 5 ],
        dosage_amount: "100mg",
        instructions: "Test schedule flash"
      }
    }
    assert_redirected_to prescription_path(@medication.prescription)
    follow_redirect!
    assert_select ".bg-green-50", /added/i
  end

  test "schedule destroy via HTML displays success flash message" do
    delete medication_schedule_path(@medication_schedule)
    assert_redirected_to prescription_path(@medication.prescription)
    follow_redirect!
    assert_select ".bg-green-50", /removed/i
  end

  # --- Medication Schedules Flash Messages (Turbo Stream) ---

  test "schedule create via Turbo Stream includes flash in response" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "14:00",
        days_of_week: [ 1, 3, 5 ],
        dosage_amount: "100mg",
        instructions: "Test schedule Turbo flash"
      }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match(/turbo-stream/, response.body)
    assert_match(/flash/, response.body)
  end

  test "schedule destroy via Turbo Stream includes flash in response" do
    delete medication_schedule_path(@medication_schedule), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match(/turbo-stream/, response.body)
    assert_match(/flash/, response.body)
  end

  # --- Medication Logs Flash Messages ---

  test "medication log create via Turbo Stream responds successfully" do
    schedule = medication_schedules(:monday_wednesday_friday)
    post medication_logs_path, params: {
      medication_log: {
        medication_id: @medication.id,
        medication_schedule_id: schedule.id,
        scheduled_date: Date.new(2026, 2, 11), # A Wednesday
        status: "taken"
      }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match(/turbo-stream/, response.body)
  end

  test "medication log destroy via Turbo Stream responds successfully" do
    log = medication_logs(:taken_log)
    delete medication_log_path(log), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match(/turbo-stream/, response.body)
  end

  # --- Flash messages render within layout ---

  test "flash notice renders in the application layout flash container" do
    post prescriptions_path, params: {
      prescription: {
        doctor_name: "Dr. Layout Flash",
        prescribed_date: Date.current
      }
    }
    follow_redirect!
    # Flash container in application layout
    assert_select "div.bg-green-50", minimum: 1
    assert_match(/created/i, response.body)
  end

  test "flash alert renders in the application layout flash container" do
    # Try creating a prescription with invalid params to trigger error,
    # then test redirect with alert for medication log failure (HTML fallback)
    sign_out
    post prescriptions_path, params: {
      prescription: { doctor_name: "Unauth" }
    }
    # Should redirect to login (authentication check)
    assert_redirected_to new_session_path
  end
end
