require "test_helper"

class SchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "show requires authentication" do
    sign_out
    get schedule_path
    assert_redirected_to new_session_path
  end

  # --- Default daily view (today) ---

  test "show renders the daily schedule view" do
    get schedule_path
    assert_response :success
    assert_select "h1", /schedule/i
  end

  test "show defaults to today when no date param" do
    get schedule_path
    assert_response :success
    # The view should show today's date
    assert_match Time.zone.today.strftime("%B"), response.body
  end

  # --- Date parameter navigation ---

  test "show accepts date parameter" do
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success
    # Should show Feb 9, 2026 (Monday)
    assert_match "February", response.body
    assert_match "9", response.body
  end

  test "show with Monday date displays schedules for Monday" do
    # Monday 2026-02-09: morning_daily (08:00), monday_wednesday_friday (12:00), evening_weekdays (20:00)
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # Should display drug names for the medications
    assert_match "Aspirin", response.body
    assert_match "Ibuprofen", response.body
  end

  test "show with Saturday date excludes weekday-only schedules" do
    # Saturday 2026-02-07: only morning_daily (08:00) is scheduled (it's every day)
    get schedule_path, params: { date: "2026-02-07" }
    assert_response :success

    # Aspirin (morning_daily) should appear
    assert_match "Aspirin", response.body
    # Ibuprofen (evening_weekdays) should NOT appear -- weekdays only
    assert_no_match(/Ibuprofen/, response.body)
  end

  # --- Display grouped by time of day ---

  test "show displays entries grouped by time of day" do
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # Time groups should be visible
    assert_match "08:00", response.body
    assert_match "12:00", response.body
    assert_match "20:00", response.body
  end

  test "show displays drug name, dosage, form, and instructions per entry" do
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # morning_daily schedule entry should show:
    # Drug: Aspirin, Dosage: 100mg, Form: tablet, Instructions: Take with breakfast
    assert_match "Aspirin", response.body
    assert_match "100mg", response.body
    assert_match "tablet", response.body
    assert_match "Take with breakfast", response.body
  end

  # --- Status indicators ---

  test "show displays pending status for entries without logs" do
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # All entries for 2026-02-09 should be pending (no logs exist for that date)
    assert_match(/pending/i, response.body)
  end

  test "show displays taken status for entries with taken log" do
    # 2026-02-10: taken_log for morning_daily at 08:00
    get schedule_path, params: { date: "2026-02-10" }
    assert_response :success

    assert_match(/taken/i, response.body)
  end

  test "show displays skipped status for entries with skipped log" do
    # 2026-02-10: skipped_log for evening_weekdays at 20:00
    get schedule_path, params: { date: "2026-02-10" }
    assert_response :success

    assert_match(/skipped/i, response.body)
  end

  # --- Overdue highlighting ---

  test "show highlights overdue medications" do
    # Travel to 14:00 on Monday Feb 9 -- 08:00 and 12:00 entries should be overdue
    travel_to Time.zone.local(2026, 2, 9, 14, 0, 0) do
      get schedule_path, params: { date: "2026-02-09" }
      assert_response :success

      # Should contain overdue indicator
      assert_match(/overdue/i, response.body)
    end
  end

  # --- Day navigation controls ---

  test "show includes previous day navigation link" do
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # Should have a link to the previous day (Feb 8)
    assert_select "a[href=?]", schedule_path(date: "2026-02-08")
  end

  test "show includes next day navigation link" do
    get schedule_path, params: { date: "2026-02-09" }
    assert_response :success

    # Should have a link to the next day (Feb 10)
    assert_select "a[href=?]", schedule_path(date: "2026-02-10")
  end

  # --- Empty state ---

  test "show handles dates with no scheduled medications gracefully" do
    # other_user has no medications with schedules
    sign_out
    sign_in_as(@other_user)

    get schedule_path
    assert_response :success
    # Should show an empty state message
    assert_match(/no medications/i, response.body)
  end

  # --- Invalid date handling ---

  test "show falls back to today for invalid date parameter" do
    get schedule_path, params: { date: "invalid-date" }
    assert_response :success
    # Should fall back to today gracefully
    assert_match Time.zone.today.strftime("%B"), response.body
  end

  # =============================================
  # Weekly view tests (Task 8.2)
  # =============================================

  # --- Authentication ---

  test "weekly requires authentication" do
    sign_out
    get weekly_schedule_path
    assert_redirected_to new_session_path
  end

  # --- Basic weekly view rendering ---

  test "weekly renders the weekly schedule overview" do
    get weekly_schedule_path
    assert_response :success
    assert_select "h1", /weekly/i
  end

  test "weekly defaults to current week when no week_start param" do
    travel_to Time.zone.local(2026, 2, 11, 10, 0, 0) do
      get weekly_schedule_path
      assert_response :success
      # Should display the Monday of the current week (Feb 9)
      assert_match "February", response.body
      assert_match "9", response.body
    end
  end

  # --- Week start parameter navigation ---

  test "weekly accepts week_start parameter" do
    get weekly_schedule_path, params: { week_start: "2026-02-09" }
    assert_response :success
    # Should show the week starting Feb 9 (Monday)
    assert_match "February", response.body
  end

  test "weekly displays all 7 days of the week" do
    get weekly_schedule_path, params: { week_start: "2026-02-09" }
    assert_response :success

    # Should display each day: Mon Feb 9 through Sun Feb 15
    assert_match "Mon", response.body
    assert_match "Tue", response.body
    assert_match "Wed", response.body
    assert_match "Thu", response.body
    assert_match "Fri", response.body
    assert_match "Sat", response.body
    assert_match "Sun", response.body
  end

  # --- Weekly content: medication details ---

  test "weekly displays medication name, dosage, and time for each day" do
    get weekly_schedule_path, params: { week_start: "2026-02-09" }
    assert_response :success

    # Monday should show Aspirin (morning_daily at 08:00 and monday_wednesday_friday at 12:00)
    # and Ibuprofen (evening_weekdays at 20:00)
    assert_match "Aspirin", response.body
    assert_match "Ibuprofen", response.body
    assert_match "08:00", response.body
    assert_match "20:00", response.body
  end

  # --- Adherence status visual distinction ---

  test "weekly visually distinguishes complete adherence day" do
    # Tuesday Feb 10: 2 schedules, 2 logs (complete)
    get weekly_schedule_path, params: { week_start: "2026-02-09" }
    assert_response :success

    # Should contain adherence indicator for complete day
    assert_match(/complete/i, response.body)
  end

  test "weekly visually distinguishes none adherence day" do
    # Monday Feb 9: 3 schedules, 0 logs (none)
    get weekly_schedule_path, params: { week_start: "2026-02-09" }
    assert_response :success

    # Should contain adherence indicator for no-adherence day
    assert_match(/none/i, response.body)
  end

  # --- Week navigation controls ---

  test "weekly includes previous week navigation link" do
    get weekly_schedule_path, params: { week_start: "2026-02-09" }
    assert_response :success

    # Previous week starts Feb 2
    assert_select "a[href=?]", weekly_schedule_path(week_start: "2026-02-02")
  end

  test "weekly includes next week navigation link" do
    get weekly_schedule_path, params: { week_start: "2026-02-09" }
    assert_response :success

    # Next week starts Feb 16
    assert_select "a[href=?]", weekly_schedule_path(week_start: "2026-02-16")
  end

  # --- Turbo Frame response ---

  test "weekly view is wrapped in a Turbo Frame" do
    get weekly_schedule_path, params: { week_start: "2026-02-09" }
    assert_response :success

    assert_select "turbo-frame#weekly_schedule"
  end

  test "weekly responds to Turbo Frame request" do
    get weekly_schedule_path, params: { week_start: "2026-02-09" },
        headers: { "Turbo-Frame" => "weekly_schedule" }
    assert_response :success
    assert_select "turbo-frame#weekly_schedule"
  end

  # --- Invalid week_start handling ---

  test "weekly falls back to current week for invalid week_start parameter" do
    get weekly_schedule_path, params: { week_start: "invalid-date" }
    assert_response :success
    # Should still render successfully
    assert_select "h1", /weekly/i
  end

  # --- Empty state ---

  test "weekly handles user with no scheduled medications" do
    sign_out
    sign_in_as(@other_user)

    get weekly_schedule_path
    assert_response :success
    # Should render without errors
    assert_select "h1", /weekly/i
  end
end
