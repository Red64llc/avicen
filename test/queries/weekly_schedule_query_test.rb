require "test_helper"

class WeeklyScheduleQueryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
  end

  # --- 7-day span correctness ---

  test "returns exactly 7 DaySummary objects" do
    # Monday 2026-02-09
    result = WeeklyScheduleQuery.new(user: @user, week_start: Date.new(2026, 2, 9)).call

    assert_equal 7, result.size
    result.each do |day_summary|
      assert_instance_of WeeklyScheduleQuery::DaySummary, day_summary
    end
  end

  test "returns days from Monday to Sunday in order" do
    week_start = Date.new(2026, 2, 9) # Monday
    result = WeeklyScheduleQuery.new(user: @user, week_start: week_start).call

    dates = result.map(&:date)
    expected_dates = (0..6).map { |i| week_start + i.days }
    assert_equal expected_dates, dates
  end

  test "each DaySummary contains entries from DailyScheduleQuery" do
    week_start = Date.new(2026, 2, 9) # Monday
    result = WeeklyScheduleQuery.new(user: @user, week_start: week_start).call

    monday_summary = result.first
    assert_equal Date.new(2026, 2, 9), monday_summary.date
    assert_instance_of Array, monday_summary.entries

    # Monday should have entries: morning_daily (08:00), monday_wednesday_friday (12:00), evening_weekdays (20:00)
    assert_equal 3, monday_summary.entries.size
    monday_summary.entries.each do |entry|
      assert_instance_of DailyScheduleQuery::ScheduleEntry, entry
    end
  end

  test "Saturday only includes daily schedule not weekday-only" do
    week_start = Date.new(2026, 2, 9) # Monday
    result = WeeklyScheduleQuery.new(user: @user, week_start: week_start).call

    # Saturday is index 5 (Mon=0, Tue=1, ..., Sat=5)
    saturday_summary = result[5]
    assert_equal Date.new(2026, 2, 14), saturday_summary.date

    # Saturday: only morning_daily (every day schedule) should be present
    assert_equal 1, saturday_summary.entries.size
    assert_equal medication_schedules(:morning_daily).id, saturday_summary.entries.first.schedule.id
  end

  test "Sunday only includes daily schedule" do
    week_start = Date.new(2026, 2, 9) # Monday
    result = WeeklyScheduleQuery.new(user: @user, week_start: week_start).call

    sunday_summary = result[6]
    assert_equal Date.new(2026, 2, 15), sunday_summary.date

    # Sunday: only morning_daily (every day schedule) should be present
    assert_equal 1, sunday_summary.entries.size
    assert_equal medication_schedules(:morning_daily).id, sunday_summary.entries.first.schedule.id
  end

  # --- Adherence status per day ---

  test "adherence_status is :empty when no medications are scheduled" do
    # other_user has no medications with schedules
    week_start = Date.new(2026, 2, 9)
    result = WeeklyScheduleQuery.new(user: @other_user, week_start: week_start).call

    result.each do |day_summary|
      assert_equal :empty, day_summary.adherence_status
      assert_equal 0, day_summary.total_scheduled
      assert_equal 0, day_summary.total_logged
    end
  end

  test "adherence_status is :none when medications are scheduled but none logged" do
    # Monday 2026-02-09: 3 schedules, no logs
    week_start = Date.new(2026, 2, 9)
    result = WeeklyScheduleQuery.new(user: @user, week_start: week_start).call

    monday_summary = result.first
    assert_equal :none, monday_summary.adherence_status
    assert_equal 3, monday_summary.total_scheduled
    assert_equal 0, monday_summary.total_logged
  end

  test "adherence_status is :partial when some but not all doses are logged" do
    # Tuesday 2026-02-10: taken_log (morning_daily), skipped_log (evening_weekdays)
    # Tuesday has 2 schedules with logs out of 2 weekday schedules + daily = 2 total
    # morning_daily + evening_weekdays are scheduled for Tuesday (wday=2)
    # taken_log + skipped_log exist
    # But monday_wednesday_friday is NOT scheduled for Tuesday (only [1,3,5])
    # So Tuesday has 2 schedules and 2 logs => should be :complete
    # Let's verify by checking a day that is partially logged
    # We need a scenario: 3 scheduled, 1 or 2 logged

    # Actually, Tuesday (wday=2) has:
    # - morning_daily [0,1,2,3,4,5,6] => YES
    # - evening_weekdays [1,2,3,4,5] => YES
    # - monday_wednesday_friday [1,3,5] => NO (not Tuesday)
    # Total scheduled: 2
    # Logs: taken_log (morning_daily) + skipped_log (evening_weekdays) = 2
    # That's complete, not partial. We need a different scenario.

    # Create a partial scenario: Monday with only 1 of 3 logged
    monday = Date.new(2026, 2, 9)
    MedicationLog.create!(
      medication: medications(:aspirin_morning),
      medication_schedule: medication_schedules(:morning_daily),
      status: :taken,
      logged_at: Time.zone.local(2026, 2, 9, 8, 15),
      scheduled_date: monday
    )

    result = WeeklyScheduleQuery.new(user: @user, week_start: monday).call
    monday_summary = result.first

    assert_equal :partial, monday_summary.adherence_status
    assert_equal 3, monday_summary.total_scheduled
    assert_equal 1, monday_summary.total_logged
  end

  test "adherence_status is :complete when all scheduled doses are logged" do
    # Tuesday 2026-02-10: 2 schedules, 2 logs (taken_log + skipped_log)
    week_start = Date.new(2026, 2, 9)
    result = WeeklyScheduleQuery.new(user: @user, week_start: week_start).call

    tuesday_summary = result[1] # Index 1 = Tuesday
    assert_equal Date.new(2026, 2, 10), tuesday_summary.date
    assert_equal :complete, tuesday_summary.adherence_status
    assert_equal 2, tuesday_summary.total_scheduled
    assert_equal 2, tuesday_summary.total_logged
  end

  test "total_logged counts both taken and skipped logs" do
    # Tuesday 2026-02-10: taken_log + skipped_log
    week_start = Date.new(2026, 2, 9)
    result = WeeklyScheduleQuery.new(user: @user, week_start: week_start).call

    tuesday_summary = result[1]
    assert_equal 2, tuesday_summary.total_logged
  end

  # --- Week boundary handling ---

  test "defaults week_start to current week Monday when nil" do
    # Travel to Wednesday Feb 11, 2026
    travel_to Time.zone.local(2026, 2, 11, 10, 0, 0) do
      result = WeeklyScheduleQuery.new(user: @user).call

      # Should start from Monday Feb 9
      assert_equal Date.new(2026, 2, 9), result.first.date
      assert_equal Date.new(2026, 2, 15), result.last.date
    end
  end

  test "defaults week_start to Monday even when today is Monday" do
    travel_to Time.zone.local(2026, 2, 9, 10, 0, 0) do
      result = WeeklyScheduleQuery.new(user: @user).call

      assert_equal Date.new(2026, 2, 9), result.first.date
    end
  end

  test "defaults week_start to Monday even when today is Sunday" do
    travel_to Time.zone.local(2026, 2, 15, 10, 0, 0) do
      result = WeeklyScheduleQuery.new(user: @user).call

      assert_equal Date.new(2026, 2, 9), result.first.date
    end
  end

  test "handles week_start that is not a Monday by snapping to previous Monday" do
    # Pass Wednesday Feb 11 as week_start -- should snap to Monday Feb 9
    result = WeeklyScheduleQuery.new(user: @user, week_start: Date.new(2026, 2, 11)).call

    assert_equal Date.new(2026, 2, 9), result.first.date
  end

  # --- User scoping ---

  test "only returns data for the specified user" do
    week_start = Date.new(2026, 2, 9)
    result = WeeklyScheduleQuery.new(user: @other_user, week_start: week_start).call

    result.each do |day_summary|
      assert_equal 0, day_summary.total_scheduled
      assert_empty day_summary.entries
    end
  end

  # --- N+1 prevention ---

  test "does not produce excessive queries across 7 days" do
    week_start = Date.new(2026, 2, 9)

    # Warm up
    WeeklyScheduleQuery.new(user: @user, week_start: week_start).call

    query_count = 0
    counter = lambda { |_name, _start, _finish, _id, _payload| query_count += 1 }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      result = WeeklyScheduleQuery.new(user: @user, week_start: week_start).call
      result.each do |day_summary|
        day_summary.entries.each do |entry|
          entry.drug_name
          entry.dosage
          entry.form
        end
      end
    end

    # With eager loading, should be a bounded number of queries (not 7x per day)
    # Expect around 2-3 queries (schedules + logs), not 14+ (7 days x 2 queries)
    assert query_count <= 10, "Expected at most 10 queries but got #{query_count} (possible N+1)"
  end
end
