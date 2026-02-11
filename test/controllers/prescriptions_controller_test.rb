require "test_helper"

class PrescriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @prescription = prescriptions(:one)
    @other_user_prescription = prescriptions(:other_user_prescription)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "index requires authentication" do
    sign_out
    get prescriptions_path
    assert_redirected_to new_session_path
  end

  test "show requires authentication" do
    sign_out
    get prescription_path(@prescription)
    assert_redirected_to new_session_path
  end

  test "new requires authentication" do
    sign_out
    get new_prescription_path
    assert_redirected_to new_session_path
  end

  test "create requires authentication" do
    sign_out
    post prescriptions_path, params: { prescription: { doctor_name: "Dr. Test", prescribed_date: Date.current } }
    assert_redirected_to new_session_path
  end

  # --- Index ---

  test "index lists prescriptions for current user ordered by prescribed date desc" do
    get prescriptions_path
    assert_response :success
    assert_select "h1", /Prescriptions/i
  end

  test "index does not include other user prescriptions" do
    get prescriptions_path
    assert_response :success
    assert_no_match @other_user_prescription.doctor_name, response.body
  end

  test "index displays active medication count per prescription" do
    get prescriptions_path
    assert_response :success
    # Prescription :one has 2 active medications (aspirin_morning and ibuprofen_evening)
    # The page should show a count of active medications
    assert_select ".prescription-card", minimum: 1
    assert_match /2 active\s+medications/, response.body
  end

  test "index orders prescriptions by prescribed date descending" do
    get prescriptions_path
    assert_response :success
    # Prescription :two has prescribed_date 2026-02-01, :one has 2026-01-15
    # :two should appear before :one in the page
    two_pos = response.body.index(prescriptions(:two).doctor_name)
    one_pos = response.body.index(prescriptions(:one).doctor_name)
    assert two_pos < one_pos, "Most recent prescription should appear first"
  end

  # --- Show ---

  test "show displays prescription details" do
    get prescription_path(@prescription)
    assert_response :success
    assert_select "h1", /#{@prescription.doctor_name}/i
  end

  test "show displays associated medications" do
    get prescription_path(@prescription)
    assert_response :success
    # Prescription :one has aspirin_morning and ibuprofen_evening
    assert_match "100mg", response.body
  end

  test "show returns not found for other user prescription" do
    get prescription_path(@other_user_prescription)
    assert_response :not_found
  end

  # --- New ---

  test "new renders the prescription form" do
    get new_prescription_path
    assert_response :success
    assert_select "form"
    assert_select "input[name='prescription[doctor_name]']"
    assert_select "input[name='prescription[prescribed_date]']"
    assert_select "textarea[name='prescription[notes]']"
  end

  # --- Create ---

  test "create with valid params creates prescription and redirects" do
    assert_difference "Prescription.count", 1 do
      post prescriptions_path, params: {
        prescription: {
          doctor_name: "Dr. New",
          prescribed_date: Date.current,
          notes: "New prescription notes"
        }
      }
    end

    prescription = Prescription.last
    assert_equal @user.id, prescription.user_id
    assert_equal "Dr. New", prescription.doctor_name
    assert_redirected_to prescription_path(prescription)
    follow_redirect!
    assert_match /created/i, flash[:notice]
  end

  test "create with invalid params re-renders form with errors" do
    assert_no_difference "Prescription.count" do
      post prescriptions_path, params: {
        prescription: {
          doctor_name: "Dr. Invalid",
          prescribed_date: nil,
          notes: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "create scopes prescription to current user" do
    post prescriptions_path, params: {
      prescription: {
        doctor_name: "Dr. Scoped",
        prescribed_date: Date.current
      }
    }

    prescription = Prescription.last
    assert_equal @user.id, prescription.user_id
  end

  # --- Edit ---

  test "edit renders the form for own prescription" do
    get edit_prescription_path(@prescription)
    assert_response :success
    assert_select "form"
    assert_select "input[name='prescription[doctor_name]'][value=?]", @prescription.doctor_name
  end

  test "edit returns not found for other user prescription" do
    get edit_prescription_path(@other_user_prescription)
    assert_response :not_found
  end

  # --- Update ---

  test "update with valid params updates prescription and redirects" do
    patch prescription_path(@prescription), params: {
      prescription: {
        doctor_name: "Dr. Updated",
        prescribed_date: Date.current,
        notes: "Updated notes"
      }
    }

    assert_redirected_to prescription_path(@prescription)
    follow_redirect!
    assert_match /updated/i, flash[:notice]
    @prescription.reload
    assert_equal "Dr. Updated", @prescription.doctor_name
  end

  test "update with invalid params re-renders form with errors" do
    patch prescription_path(@prescription), params: {
      prescription: { prescribed_date: nil }
    }

    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "update returns not found for other user prescription" do
    patch prescription_path(@other_user_prescription), params: {
      prescription: { doctor_name: "Hacked" }
    }
    assert_response :not_found
  end

  # --- Destroy ---

  test "destroy deletes prescription and redirects to index" do
    assert_difference "Prescription.count", -1 do
      delete prescription_path(@prescription)
    end

    assert_redirected_to prescriptions_path
    follow_redirect!
    assert_match /deleted/i, flash[:notice]
  end

  test "destroy cascades to medications, schedules, and logs" do
    # Prescription :one has medications: aspirin_morning, ibuprofen_evening
    # aspirin_morning has schedules: morning_daily, monday_wednesday_friday
    # ibuprofen_evening has schedule: evening_weekdays
    # There are logs for morning_daily and evening_weekdays

    medication_count = @prescription.medications.count
    schedule_count = MedicationSchedule.joins(:medication).where(medications: { prescription_id: @prescription.id }).count
    log_count = MedicationLog.joins(:medication).where(medications: { prescription_id: @prescription.id }).count

    assert medication_count > 0, "Test requires prescription with medications"
    assert schedule_count > 0, "Test requires medications with schedules"
    assert log_count > 0, "Test requires schedules with logs"

    assert_difference "Medication.count", -medication_count do
      assert_difference "MedicationSchedule.count", -schedule_count do
        assert_difference "MedicationLog.count", -log_count do
          delete prescription_path(@prescription)
        end
      end
    end
  end

  test "destroy returns not found for other user prescription" do
    delete prescription_path(@other_user_prescription)
    assert_response :not_found
  end

  # --- Strong Parameters ---

  test "create ignores user_id in params" do
    post prescriptions_path, params: {
      prescription: {
        doctor_name: "Dr. Sneaky",
        prescribed_date: Date.current,
        user_id: @other_user.id
      }
    }

    prescription = Prescription.last
    assert_equal @user.id, prescription.user_id
    assert_not_equal @other_user.id, prescription.user_id
  end
end
