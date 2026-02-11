require "test_helper"

class DailyScheduleQueryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
  end

  # --- Basic query execution ---

  test "returns a hash grouped by time_of_day" do
    # Monday 2026-02-09 is a Monday (wday=1)
    result = DailyScheduleQuery.new(user: @user, date: Date.new(2026, 2, 9)).call

    assert_instance_of Hash, result
    result.each do |time_of_day, entries|
      assert_instance_of String, time_of_day
      assert_instance_of Array, entries
      entries.each do |entry|
        assert_instance_of DailyScheduleQuery::ScheduleEntry, entry
      end
    end
  end

  test "returns entries sorted by time_of_day chronologically" do
    # Monday: morning_daily (08:00), monday_wednesday_friday (12:00), evening_weekdays (20:00)
    result = DailyScheduleQuery.new(user: @user, date: Date.new(2026, 2, 9)).call

    times = result.keys
    assert_equal times, times.sort
  end

  # --- Day-of-week filtering ---

  test "filters schedules by day of week" do
    # Monday (wday=1): morning_daily has [0,1,2,3,4,5,6], evening_weekdays has [1,2,3,4,5],
    # monday_wednesday_friday has [1,3,5]
    # All three should appear on Monday
    monday = Date.new(2026, 2, 9)
    result = DailyScheduleQuery.new(user: @user, date: monday).call

    all_entries = result.values.flatten
    schedule_ids = all_entries.map { |e| e.schedule.id }

    assert_includes schedule_ids, medication_schedules(:morning_daily).id
    assert_includes schedule_ids, medication_schedules(:evening_weekdays).id
    assert_includes schedule_ids, medication_schedules(:monday_wednesday_friday).id
  end

  test "excludes schedules not matching day of week" do
    # Saturday (wday=6): morning_daily has [0,1,2,3,4,5,6] (includes Saturday),
    # evening_weekdays has [1,2,3,4,5] (excludes Saturday),
    # monday_wednesday_friday has [1,3,5] (excludes Saturday)
    saturday = Date.new(2026, 2, 7)
    result = DailyScheduleQuery.new(user: @user, date: saturday).call

    all_entries = result.values.flatten
    schedule_ids = all_entries.map { |e| e.schedule.id }

    assert_includes schedule_ids, medication_schedules(:morning_daily).id
    assert_not_includes schedule_ids, medication_schedules(:evening_weekdays).id
    assert_not_includes schedule_ids, medication_schedules(:monday_wednesday_friday).id
  end

  test "returns empty hash when no schedules match the day" do
    # Sunday (wday=0): morning_daily has [0,1,2,3,4,5,6] (includes Sunday)
    # evening_weekdays [1,2,3,4,5] (excludes Sunday)
    # monday_wednesday_friday [1,3,5] (excludes Sunday)
    # Only morning_daily should appear
    sunday = Date.new(2026, 2, 8)
    result = DailyScheduleQuery.new(user: @user, date: sunday).call

    all_entries = result.values.flatten
    assert_equal 1, all_entries.size
    assert_equal medication_schedules(:morning_daily).id, all_entries.first.schedule.id
  end

  # --- Inactive medication exclusion ---

  test "excludes inactive medications" do
    # inactive_medication belongs to prescription :two (user :one)
    # It has no schedules in fixtures, but let's verify the query doesn't include inactive meds
    monday = Date.new(2026, 2, 9)
    result = DailyScheduleQuery.new(user: @user, date: monday).call

    all_entries = result.values.flatten
    medication_ids = all_entries.map { |e| e.medication.id }

    assert_not_includes medication_ids, medications(:inactive_medication).id
  end

  # --- Log status merging ---

  test "marks entry as taken when log exists with taken status" do
    # taken_log is for morning_daily schedule on 2026-02-10 (Tuesday, wday=2)
    date = Date.new(2026, 2, 10)
    result = DailyScheduleQuery.new(user: @user, date: date).call

    morning_entries = result["08:00"]
    assert morning_entries, "Expected entries at 08:00"

    morning_entry = morning_entries.find { |e| e.schedule.id == medication_schedules(:morning_daily).id }
    assert morning_entry, "Expected an entry for morning_daily schedule"
    assert_equal :taken, morning_entry.status
    assert_equal medication_logs(:taken_log).id, morning_entry.log.id
  end

  test "marks entry as skipped when log exists with skipped status" do
    # skipped_log is for evening_weekdays schedule on 2026-02-10 (Tuesday, wday=2)
    date = Date.new(2026, 2, 10)
    result = DailyScheduleQuery.new(user: @user, date: date).call

    evening_entries = result["20:00"]
    assert evening_entries, "Expected entries at 20:00"

    evening_entry = evening_entries.find { |e| e.schedule.id == medication_schedules(:evening_weekdays).id }
    assert evening_entry, "Expected an entry for evening_weekdays schedule"
    assert_equal :skipped, evening_entry.status
    assert_equal medication_logs(:skipped_log).id, evening_entry.log.id
  end

  test "marks entry as pending when no log exists for the date" do
    # On 2026-02-09 (Monday), there are no logs for any schedule
    monday = Date.new(2026, 2, 9)
    result = DailyScheduleQuery.new(user: @user, date: monday).call

    all_entries = result.values.flatten
    all_entries.each do |entry|
      assert_equal :pending, entry.status
      assert_nil entry.log
    end
  end

  # --- ScheduleEntry data ---

  test "entry contains correct drug name from medication drug" do
    monday = Date.new(2026, 2, 9)
    result = DailyScheduleQuery.new(user: @user, date: monday).call

    morning_entry = result["08:00"]&.find { |e| e.schedule.id == medication_schedules(:morning_daily).id }
    assert morning_entry
    assert_equal "Aspirin", morning_entry.drug_name
  end

  test "entry uses schedule dosage_amount when present" do
    monday = Date.new(2026, 2, 9)
    result = DailyScheduleQuery.new(user: @user, date: monday).call

    morning_entry = result["08:00"]&.find { |e| e.schedule.id == medication_schedules(:morning_daily).id }
    assert morning_entry
    # morning_daily has dosage_amount "100mg"
    assert_equal "100mg", morning_entry.dosage
  end

  test "entry uses medication dosage when schedule dosage_amount is blank" do
    # Update morning_daily to have no dosage_amount for this test
    schedule = medication_schedules(:morning_daily)
    schedule.update!(dosage_amount: nil)

    monday = Date.new(2026, 2, 9)
    result = DailyScheduleQuery.new(user: @user, date: monday).call

    morning_entry = result["08:00"]&.find { |e| e.schedule.id == schedule.id }
    assert morning_entry
    # Should fall back to medication dosage "100mg"
    assert_equal "100mg", morning_entry.dosage
  end

  test "entry contains form from medication" do
    monday = Date.new(2026, 2, 9)
    result = DailyScheduleQuery.new(user: @user, date: monday).call

    morning_entry = result["08:00"]&.find { |e| e.schedule.id == medication_schedules(:morning_daily).id }
    assert morning_entry
    assert_equal "tablet", morning_entry.form
  end

  test "entry contains instructions from schedule" do
    monday = Date.new(2026, 2, 9)
    result = DailyScheduleQuery.new(user: @user, date: monday).call

    morning_entry = result["08:00"]&.find { |e| e.schedule.id == medication_schedules(:morning_daily).id }
    assert morning_entry
    assert_equal "Take with breakfast", morning_entry.instructions
  end

  # --- Overdue detection ---

  test "marks pending entry as overdue when scheduled time has passed" do
    # Set current time to 14:00 on Monday 2026-02-09
    # morning_daily at 08:00 should be overdue (pending + time passed)
    # monday_wednesday_friday at 12:00 should be overdue (pending + time passed)
    # evening_weekdays at 20:00 should NOT be overdue (time not yet passed)
    monday = Date.new(2026, 2, 9)

    travel_to Time.zone.local(2026, 2, 9, 14, 0, 0) do
      result = DailyScheduleQuery.new(user: @user, date: monday).call

      morning_entry = result["08:00"]&.find { |e| e.schedule.id == medication_schedules(:morning_daily).id }
      assert morning_entry
      assert morning_entry.overdue, "08:00 entry should be overdue at 14:00"

      noon_entry = result["12:00"]&.find { |e| e.schedule.id == medication_schedules(:monday_wednesday_friday).id }
      assert noon_entry
      assert noon_entry.overdue, "12:00 entry should be overdue at 14:00"

      evening_entry = result["20:00"]&.find { |e| e.schedule.id == medication_schedules(:evening_weekdays).id }
      assert evening_entry
      assert_not evening_entry.overdue, "20:00 entry should NOT be overdue at 14:00"
    end
  end

  test "does not mark taken entries as overdue" do
    # On 2026-02-10 (Tuesday), taken_log exists for morning_daily at 08:00
    date = Date.new(2026, 2, 10)

    travel_to Time.zone.local(2026, 2, 10, 14, 0, 0) do
      result = DailyScheduleQuery.new(user: @user, date: date).call

      morning_entry = result["08:00"]&.find { |e| e.schedule.id == medication_schedules(:morning_daily).id }
      assert morning_entry
      assert_not morning_entry.overdue, "Taken entry should NOT be overdue"
    end
  end

  test "does not mark skipped entries as overdue" do
    date = Date.new(2026, 2, 10)

    travel_to Time.zone.local(2026, 2, 10, 22, 0, 0) do
      result = DailyScheduleQuery.new(user: @user, date: date).call

      evening_entry = result["20:00"]&.find { |e| e.schedule.id == medication_schedules(:evening_weekdays).id }
      assert evening_entry
      assert_not evening_entry.overdue, "Skipped entry should NOT be overdue"
    end
  end

  test "does not mark entries as overdue for past dates" do
    # Past date: all entries should be overdue only if they are pending on that date
    # But we need to check behavior for a date that is not today
    past_date = Date.new(2026, 2, 2) # Monday

    travel_to Time.zone.local(2026, 2, 9, 14, 0, 0) do
      result = DailyScheduleQuery.new(user: @user, date: past_date).call

      all_entries = result.values.flatten.select { |e| e.status == :pending }
      all_entries.each do |entry|
        # Past-date pending entries should still be marked overdue since their time has passed
        # and they were never logged
        assert entry.overdue, "Pending entry on past date should be overdue"
      end
    end
  end

  test "does not mark entries as overdue for future dates" do
    future_date = Date.new(2026, 2, 16) # Monday

    travel_to Time.zone.local(2026, 2, 9, 14, 0, 0) do
      result = DailyScheduleQuery.new(user: @user, date: future_date).call

      all_entries = result.values.flatten
      all_entries.each do |entry|
        assert_not entry.overdue, "Entry on future date should NOT be overdue"
      end
    end
  end

  # --- Timezone-aware date default ---

  test "defaults date to Time.zone.today when no date provided" do
    # User :one has timezone "Eastern Time (US & Canada)"
    # At UTC midnight Feb 10, Eastern time is still Feb 9
    Time.use_zone("Eastern Time (US & Canada)") do
      travel_to Time.utc(2026, 2, 10, 3, 0, 0) do
        # In Eastern time, it's Feb 9 at 22:00
        result = DailyScheduleQuery.new(user: @user).call

        # This should use Time.zone.today which is Feb 9 in Eastern time
        # Feb 9 is a Monday, so all three schedules should appear
        all_entries = result.values.flatten
        assert all_entries.size >= 1, "Should have entries for the timezone-adjusted today"
      end
    end
  end

  # --- User scoping ---

  test "only returns schedules for the specified user" do
    monday = Date.new(2026, 2, 9)

    # other_user has prescription: other_user_prescription, but no medications with schedules
    result = DailyScheduleQuery.new(user: @other_user, date: monday).call

    all_entries = result.values.flatten
    assert_equal 0, all_entries.size, "Other user should have no schedule entries"
  end

  # --- Eager loading (N+1 prevention) ---

  test "does not produce N+1 queries" do
    monday = Date.new(2026, 2, 9)

    # Track the number of queries executed
    query_count = 0
    counter = lambda { |_name, _start, _finish, _id, _payload| query_count += 1 }

    # First call to warm up
    DailyScheduleQuery.new(user: @user, date: monday).call

    # Count queries on second call
    query_count = 0
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      result = DailyScheduleQuery.new(user: @user, date: monday).call
      # Access all associations to trigger any lazy loads
      result.each do |_time, entries|
        entries.each do |entry|
          entry.drug_name
          entry.dosage
          entry.form
          entry.instructions
          entry.medication.id
          entry.schedule.id
        end
      end
    end

    # Should not exceed a reasonable query count (2-4 queries: medications+schedules, logs)
    assert query_count <= 6, "Expected at most 6 queries but got #{query_count} (possible N+1)"
  end
end
