require "test_helper"

class ScheduleViewsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @prescription = prescriptions(:one)
    @medication = medications(:aspirin_morning)
    @schedule = medication_schedules(:morning_daily)
    @second_schedule = medication_schedules(:monday_wednesday_friday)
    sign_in_as(@user)
  end

  # ==========================================================================
  # Schedule Form -- Time-of-Day Input (Req 4.2, 4.3)
  # ==========================================================================

  test "new schedule form renders time-of-day input field" do
    get new_medication_medication_schedule_path(@medication)
    assert_response :success
    assert_select "input[name='medication_schedule[time_of_day]']"
  end

  test "new schedule form renders time-of-day as time field type" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "input[type='time'][name='medication_schedule[time_of_day]']"
  end

  test "new schedule form renders time-of-day label" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "label", text: /Time of Day/
  end

  # ==========================================================================
  # Schedule Form -- Day-of-Week Checkboxes (Req 4.4, 4.7)
  # ==========================================================================

  test "new schedule form renders seven day-of-week checkboxes" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "input[type='checkbox'][name='medication_schedule[days_of_week][]']", count: 7
  end

  test "new schedule form renders checkbox for each day of week with correct values" do
    get new_medication_medication_schedule_path(@medication)
    (0..6).each do |day_index|
      assert_select "input[type='checkbox'][name='medication_schedule[days_of_week][]'][value='#{day_index}']"
    end
  end

  test "new schedule form renders day-of-week labels for all days" do
    get new_medication_medication_schedule_path(@medication)
    MedicationSchedule::DAY_NAMES.each do |day_name|
      assert_select "span", text: day_name
    end
  end

  test "new schedule form renders days of week fieldset with legend" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "fieldset" do
      assert_select "legend", text: /Days of Week/
    end
  end

  test "edit schedule form pre-checks selected days of week" do
    get edit_medication_schedule_path(@schedule)
    assert_response :success
    @schedule.days_of_week.each do |day_index|
      assert_select "input[type='checkbox'][name='medication_schedule[days_of_week][]'][value='#{day_index}'][checked]"
    end
  end

  # ==========================================================================
  # Schedule Form -- Optional Dosage Amount Override (Req 4.2, 4.5)
  # ==========================================================================

  test "new schedule form renders dosage amount field" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "input[name='medication_schedule[dosage_amount]']"
  end

  test "new schedule form labels dosage amount as optional" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "label", text: /Dosage Amount.*optional/i
  end

  test "edit schedule form pre-fills dosage amount" do
    get edit_medication_schedule_path(@schedule)
    assert_select "input[name='medication_schedule[dosage_amount]'][value=?]", @schedule.dosage_amount
  end

  # ==========================================================================
  # Schedule Form -- Conditional Instructions (Req 4.8)
  # ==========================================================================

  test "new schedule form renders instructions textarea" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "textarea[name='medication_schedule[instructions]']"
  end

  test "new schedule form labels instructions as optional" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "label", text: /Instructions.*optional/i
  end

  test "edit schedule form pre-fills instructions" do
    get edit_medication_schedule_path(@schedule)
    assert_select "textarea[name='medication_schedule[instructions]']", text: @schedule.instructions
  end

  # ==========================================================================
  # Schedule Form -- Submit and Cancel (Req 4.6)
  # ==========================================================================

  test "new schedule form renders Add Schedule submit button" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "input[type='submit'][value='Add Schedule']"
  end

  test "edit schedule form renders Update Schedule submit button" do
    get edit_medication_schedule_path(@schedule)
    assert_select "input[type='submit'][value='Update Schedule']"
  end

  test "new schedule form renders cancel link" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "a", text: /Cancel/
  end

  # ==========================================================================
  # Schedule Form -- Validation Errors Display
  # ==========================================================================

  test "schedule form displays validation errors when present" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: { time_of_day: "", days_of_week: [] }
    }
    assert_response :unprocessable_entity
    assert_select "[class*='red']", minimum: 1
  end

  test "schedule form displays error messages for missing time_of_day" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: { time_of_day: "", days_of_week: [ 1, 2, 3 ] }
    }
    assert_response :unprocessable_entity
    assert_match(/Time of day.*blank|can't be blank/i, response.body)
  end

  test "schedule form displays error messages for missing days_of_week" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: { time_of_day: "08:00", days_of_week: [] }
    }
    assert_response :unprocessable_entity
    assert_match(/days.*week|at least one day/i, response.body)
  end

  # ==========================================================================
  # Schedule Form -- Turbo Frame Wrapping (Req 4.6)
  # ==========================================================================

  test "new schedule form is wrapped in schedule_form turbo frame" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "turbo-frame#schedule_form"
  end

  test "edit schedule form is wrapped in schedule entry turbo frame" do
    get edit_medication_schedule_path(@schedule)
    dom_id = ActionView::RecordIdentifier.dom_id(@schedule)
    assert_select "turbo-frame##{dom_id}"
  end

  test "new schedule form renders heading Add Schedule" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "h2", text: /Add Schedule/
  end

  test "edit schedule form renders heading Edit Schedule" do
    get edit_medication_schedule_path(@schedule)
    assert_select "h2", text: /Edit Schedule/
  end

  # ==========================================================================
  # Schedule Entry Partial -- Turbo Frame Rendering (Req 4.5, 4.6)
  # ==========================================================================

  test "schedule entry is wrapped in a turbo frame with dom_id" do
    get prescription_path(@prescription)
    dom_id = ActionView::RecordIdentifier.dom_id(@schedule)
    assert_select "turbo-frame##{dom_id}"
  end

  test "schedule entry displays time of day" do
    get prescription_path(@prescription)
    assert_match @schedule.time_of_day, response.body
  end

  test "schedule entry displays day-of-week names" do
    get prescription_path(@prescription)
    @schedule.days_of_week_names.each do |day_name|
      assert_match day_name, response.body
    end
  end

  test "schedule entry displays dosage amount when present" do
    get prescription_path(@prescription)
    assert_match @schedule.dosage_amount, response.body
  end

  test "schedule entry displays instructions when present" do
    get prescription_path(@prescription)
    assert_match @schedule.instructions, response.body
  end

  test "schedule entry renders edit link" do
    get prescription_path(@prescription)
    assert_select "a[href=?]", edit_medication_schedule_path(@schedule), text: /Edit/
  end

  test "schedule entry renders remove button" do
    get prescription_path(@prescription)
    assert_select "form[action=?]", medication_schedule_path(@schedule) do
      assert_select "button", text: /Remove/
    end
  end

  test "schedule entry remove button has turbo confirmation" do
    get prescription_path(@prescription)
    assert_match(/data-turbo-confirm/, response.body)
  end

  # ==========================================================================
  # Schedule List Within Medication Detail (Req 4.5)
  # ==========================================================================

  test "medication detail displays schedules section heading" do
    get prescription_path(@prescription)
    assert_select "h3", text: /Schedules/
  end

  test "medication detail displays add schedule link" do
    get prescription_path(@prescription)
    assert_select "a[href=?]", new_medication_medication_schedule_path(@medication), text: /Add Schedule/
  end

  test "medication detail renders schedule entries in schedules_list container" do
    get prescription_path(@prescription)
    assert_select "#schedules_list_medication_#{@medication.id}"
  end

  test "medication detail displays all schedule entries for medication" do
    get prescription_path(@prescription)
    @medication.medication_schedules.each do |schedule|
      dom_id = ActionView::RecordIdentifier.dom_id(schedule)
      assert_select "turbo-frame##{dom_id}"
    end
  end

  # ==========================================================================
  # Multiple Schedules Per Medication (Req 4.5)
  # ==========================================================================

  test "medication with multiple schedules shows all schedule entries" do
    get prescription_path(@prescription)
    # aspirin_morning has morning_daily and monday_wednesday_friday schedules
    assert_match @schedule.time_of_day, response.body
    assert_match @second_schedule.time_of_day, response.body
  end

  test "medication with multiple schedules shows different dosage amounts" do
    get prescription_path(@prescription)
    assert_match @schedule.dosage_amount, response.body
    assert_match @second_schedule.dosage_amount, response.body
  end

  test "multiple schedules are rendered in ordered_by_time order" do
    get prescription_path(@prescription)
    # morning_daily is 08:00, monday_wednesday_friday is 12:00
    first_pos = response.body.index(@schedule.time_of_day)
    second_pos = response.body.index(@second_schedule.time_of_day)
    assert first_pos < second_pos, "Expected 08:00 schedule to appear before 12:00 schedule"
  end

  # ==========================================================================
  # Schedule-Builder Stimulus Controller Integration (Req 4.6)
  # ==========================================================================

  test "medication detail renders schedule-builder stimulus controller" do
    get prescription_path(@prescription)
    assert_select "[data-controller='schedule-builder']"
  end

  test "schedule-builder controller has medication-id value" do
    get prescription_path(@prescription)
    assert_select "[data-schedule-builder-medication-id-value='#{@medication.id}']"
  end

  test "schedule-builder controller has list target" do
    get prescription_path(@prescription)
    assert_select "[data-schedule-builder-target='list']"
  end

  test "add schedule link targets the schedule_form turbo frame" do
    get prescription_path(@prescription)
    assert_select "a[data-turbo-frame='schedule_form'][href=?]", new_medication_medication_schedule_path(@medication)
  end

  test "add schedule link triggers schedule-builder add action" do
    get prescription_path(@prescription)
    assert_select "a[data-action*='schedule-builder#add']"
  end

  # ==========================================================================
  # Prescription Show -- Schedule Form Placeholder (Req 4.6)
  # ==========================================================================

  test "prescription show has empty schedule_form turbo frame placeholder" do
    get prescription_path(@prescription)
    assert_select "turbo-frame#schedule_form"
  end

  # ==========================================================================
  # Turbo Stream Responses for Schedule CRUD (Req 4.6)
  # ==========================================================================

  test "create turbo stream appends schedule to schedules_list" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "15:00",
        days_of_week: [ 1, 2, 3, 4, 5 ]
      }
    }, as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream.*action="append".*target="schedules_list_medication_#{@medication.id}"/m, response.body)
  end

  test "create turbo stream clears the schedule_form frame" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "15:00",
        days_of_week: [ 1, 2, 3, 4, 5 ]
      }
    }, as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream.*action="update".*target="schedule_form"/m, response.body)
  end

  test "update turbo stream replaces the schedule entry" do
    patch medication_schedule_path(@schedule), params: {
      medication_schedule: { time_of_day: "10:00" }
    }, as: :turbo_stream

    assert_response :success
    dom_id = ActionView::RecordIdentifier.dom_id(@schedule)
    assert_match(/turbo-stream.*action="replace".*target="#{dom_id}"/m, response.body)
  end

  test "destroy turbo stream removes the schedule entry" do
    delete medication_schedule_path(@schedule), as: :turbo_stream

    assert_response :success
    dom_id = ActionView::RecordIdentifier.dom_id(@schedule)
    assert_match(/turbo-stream.*action="remove".*target="#{dom_id}"/m, response.body)
  end

  # ==========================================================================
  # Empty State (Req 4.5)
  # ==========================================================================

  test "medication with no schedules shows empty state message" do
    # Create a medication with no schedules
    med_without_schedules = Medication.create!(
      prescription: @prescription,
      drug: drugs(:ibuprofen),
      dosage: "400mg",
      form: "capsule"
    )

    get prescription_path(@prescription)
    assert_match(/No schedules configured/i, response.body)
  end

  # ==========================================================================
  # Unique Schedule List IDs Per Medication (Req 4.5, 4.6)
  # ==========================================================================

  test "each medication has a unique schedules_list container id" do
    get prescription_path(@prescription)
    # With multiple medications on the page, schedule list IDs must be unique
    # to ensure Turbo Stream append targets the correct medication's list
    @prescription.medications.each do |medication|
      assert_select "#schedules_list_medication_#{medication.id}"
    end
  end

  test "create turbo stream appends to medication-specific schedules_list" do
    post medication_medication_schedules_path(@medication), params: {
      medication_schedule: {
        time_of_day: "15:00",
        days_of_week: [ 1, 2, 3, 4, 5 ]
      }
    }, as: :turbo_stream

    assert_response :success
    assert_match(/target="schedules_list_medication_#{@medication.id}"/, response.body)
  end

  # ==========================================================================
  # Empty State Always Present in DOM (Req 4.6)
  # ==========================================================================

  test "empty state element is always present in DOM for schedule-builder controller" do
    get prescription_path(@prescription)
    # Even when schedules exist, empty target should be in the DOM (hidden)
    # so the Stimulus controller can show it when all entries are removed
    assert_select "[data-schedule-builder-target='empty']", minimum: 1
  end

  # ==========================================================================
  # Responsive Layout (Req 11.2)
  # ==========================================================================

  test "schedule form uses responsive tailwind classes" do
    get new_medication_medication_schedule_path(@medication)
    assert_select "input[class*='w-full']", minimum: 1
  end

  test "schedule entries use responsive flex layout" do
    get prescription_path(@prescription)
    assert_match(/sm:flex-row|sm:items-center/, response.body)
  end

  test "schedule entry actions use responsive spacing" do
    get prescription_path(@prescription)
    assert_match(/sm:mt-0/, response.body)
  end
end
