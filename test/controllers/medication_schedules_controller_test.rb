require "test_helper"

class MedicationSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @prescription = prescriptions(:one)
    @other_user_prescription = prescriptions(:other_user_prescription)
    @medication = medications(:aspirin_morning)
    @schedule = medication_schedules(:morning_daily)
    @drug = drugs(:aspirin)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "create requires authentication" do
    sign_out
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "09:00",
        days_of_week: [ 1, 2, 3 ]
      }
    }
    assert_redirected_to new_session_path
  end

  test "update requires authentication" do
    sign_out
    patch medication_schedule_path(@schedule), params: {
      medication_schedule: { time_of_day: "10:00" }
    }
    assert_redirected_to new_session_path
  end

  test "destroy requires authentication" do
    sign_out
    delete medication_schedule_path(@schedule)
    assert_redirected_to new_session_path
  end

  # --- Create ---

  test "create with valid params creates schedule nested under medication" do
    assert_difference "MedicationSchedule.count", 1 do
      post medication_medication_schedules_path(@medication), params: {
        medication_schedule: {
          time_of_day: "14:00",
          days_of_week: [ 1, 3, 5 ],
          dosage_amount: "75mg",
          instructions: "Take with lunch"
        }
      }, as: :turbo_stream
    end

    schedule = MedicationSchedule.last
    assert_equal @medication.id, schedule.medication_id
    assert_equal "14:00", schedule.time_of_day
    assert_equal [ 1, 3, 5 ], schedule.days_of_week
    assert_equal "75mg", schedule.dosage_amount
    assert_equal "Take with lunch", schedule.instructions
  end

  test "create with day-of-week array correctly stores all seven days" do
    all_days = [ 0, 1, 2, 3, 4, 5, 6 ]
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "08:00",
        days_of_week: all_days
      }
    }, as: :turbo_stream

    schedule = MedicationSchedule.last
    assert_equal all_days, schedule.days_of_week
  end

  test "create responds with Turbo Stream append" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "09:00",
        days_of_week: [ 1, 2, 3, 4, 5 ]
      }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_match "turbo-stream", response.body
    assert_match "append", response.body
  end

  test "create with HTML format redirects to medication prescription" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "09:00",
        days_of_week: [ 1, 2, 3, 4, 5 ]
      }
    }

    assert_response :redirect
  end

  test "create with invalid params re-renders with errors" do
    assert_no_difference "MedicationSchedule.count" do
      post medication_medication_schedules_path(@medication), params: {
        medication_schedule: {
          time_of_day: "",
          days_of_week: []
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create returns not found for medication belonging to other user" do
    other_medication = Medication.create!(
      prescription: @other_user_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )

    assert_no_difference "MedicationSchedule.count" do
      post medication_medication_schedules_path(other_medication), params: {
        medication_schedule: {
          time_of_day: "09:00",
          days_of_week: [ 1, 2, 3 ]
        }
      }
    end

    assert_response :not_found
  end

  # --- Update ---

  test "update with valid params updates schedule" do
    patch medication_schedule_path(@schedule), params: {
      medication_schedule: {
        time_of_day: "09:30",
        dosage_amount: "150mg",
        instructions: "Updated instructions"
      }
    }

    @schedule.reload
    assert_equal "09:30", @schedule.time_of_day
    assert_equal "150mg", @schedule.dosage_amount
    assert_equal "Updated instructions", @schedule.instructions
  end

  test "update responds with Turbo Stream replace" do
    patch medication_schedule_path(@schedule), params: {
      medication_schedule: { time_of_day: "10:00" }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_match "turbo-stream", response.body
    assert_match "replace", response.body
  end

  test "update with HTML format redirects" do
    patch medication_schedule_path(@schedule), params: {
      medication_schedule: { time_of_day: "10:00" }
    }

    assert_response :redirect
  end

  test "update with invalid params re-renders with errors" do
    patch medication_schedule_path(@schedule), params: {
      medication_schedule: { time_of_day: "", days_of_week: [] }
    }

    assert_response :unprocessable_entity
  end

  test "update returns not found for schedule belonging to other user" do
    other_medication = Medication.create!(
      prescription: @other_user_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )
    other_schedule = MedicationSchedule.create!(
      medication: other_medication,
      time_of_day: "08:00",
      days_of_week: [ 1, 2, 3 ]
    )

    patch medication_schedule_path(other_schedule), params: {
      medication_schedule: { time_of_day: "23:00" }
    }

    assert_response :not_found
    other_schedule.reload
    assert_equal "08:00", other_schedule.time_of_day
  end

  # --- Destroy ---

  test "destroy deletes schedule and redirects for HTML format" do
    assert_difference "MedicationSchedule.count", -1 do
      delete medication_schedule_path(@schedule)
    end

    assert_response :redirect
  end

  test "destroy responds with Turbo Stream remove" do
    assert_difference "MedicationSchedule.count", -1 do
      delete medication_schedule_path(@schedule), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_match "turbo-stream", response.body
    assert_match "remove", response.body
  end

  test "destroy returns not found for schedule belonging to other user" do
    other_medication = Medication.create!(
      prescription: @other_user_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )
    other_schedule = MedicationSchedule.create!(
      medication: other_medication,
      time_of_day: "08:00",
      days_of_week: [ 1, 2, 3 ]
    )

    assert_no_difference "MedicationSchedule.count" do
      delete medication_schedule_path(other_schedule)
    end

    assert_response :not_found
  end

  # --- User Scoping ---

  test "schedule access is scoped through current user prescriptions chain" do
    other_medication = Medication.create!(
      prescription: @other_user_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )
    other_schedule = MedicationSchedule.create!(
      medication: other_medication,
      time_of_day: "08:00",
      days_of_week: [ 1, 2, 3 ]
    )

    # All member actions should return not found
    patch medication_schedule_path(other_schedule), params: {
      medication_schedule: { time_of_day: "23:00" }
    }
    assert_response :not_found

    delete medication_schedule_path(other_schedule)
    assert_response :not_found
  end

  # --- Strong Parameters ---

  test "create ignores medication_id in params" do
    other_medication = Medication.create!(
      prescription: @other_user_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )

    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "14:00",
        days_of_week: [ 1, 2, 3 ],
        medication_id: other_medication.id
      }
    }

    schedule = MedicationSchedule.last
    assert_equal @medication.id, schedule.medication_id
    assert_not_equal other_medication.id, schedule.medication_id
  end

  # --- Turbo Stream Content ---

  test "create turbo_stream response includes schedule details" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "15:30",
        days_of_week: [ 1, 3, 5 ],
        dosage_amount: "250mg",
        instructions: "Take with water"
      }
    }, as: :turbo_stream

    assert_response :success
    assert_match "15:30", response.body
  end

  test "update turbo_stream response includes updated schedule" do
    patch medication_schedule_path(@schedule), params: {
      medication_schedule: { time_of_day: "11:45" }
    }, as: :turbo_stream

    assert_response :success
    assert_match "11:45", response.body
  end

  test "destroy turbo_stream response targets schedule dom_id for removal" do
    schedule_dom_id = ActionView::RecordIdentifier.dom_id(@schedule)

    delete medication_schedule_path(@schedule), as: :turbo_stream

    assert_response :success
    assert_match schedule_dom_id, response.body
  end

  # --- New (form for creating) ---

  test "new renders the schedule form" do
    get new_medication_medication_schedule_path(@medication)
    assert_response :success
    assert_select "form"
  end

  test "new returns not found for medication belonging to other user" do
    other_medication = Medication.create!(
      prescription: @other_user_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )

    get new_medication_medication_schedule_path(other_medication)
    assert_response :not_found
  end
end
