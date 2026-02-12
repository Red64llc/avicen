require "test_helper"

class MedicationLogTest < ActiveSupport::TestCase
  test "taken enum value" do
    log = medication_logs(:taken_log)
    assert log.taken?
    assert_not log.skipped?
  end

  test "skipped enum value" do
    log = medication_logs(:skipped_log)
    assert log.skipped?
    assert_not log.taken?
  end

  test "validates scheduled_date presence" do
    log = MedicationLog.new(
      medication: medications(:aspirin_morning),
      medication_schedule: medication_schedules(:morning_daily),
      status: :taken,
      scheduled_date: nil
    )
    assert_not log.valid?
    assert_includes log.errors[:scheduled_date], "can't be blank"
  end

  test "validates uniqueness of medication_schedule_id scoped to scheduled_date" do
    existing = medication_logs(:taken_log)
    duplicate = MedicationLog.new(
      medication: existing.medication,
      medication_schedule: existing.medication_schedule,
      status: :skipped,
      scheduled_date: existing.scheduled_date,
      logged_at: Time.current
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:medication_schedule_id], "has already been taken"
  end

  test "allows same schedule on different dates" do
    existing = medication_logs(:taken_log)
    different_date = MedicationLog.new(
      medication: existing.medication,
      medication_schedule: existing.medication_schedule,
      status: :taken,
      scheduled_date: existing.scheduled_date + 1.day,
      logged_at: Time.current
    )
    assert different_date.valid?
  end

  test "for_date scope returns logs for a specific date" do
    date = Date.new(2026, 2, 10)
    logs = MedicationLog.for_date(date)
    assert_includes logs, medication_logs(:taken_log)
    assert_includes logs, medication_logs(:skipped_log)
  end

  test "for_date scope excludes logs for other dates" do
    other_date = Date.new(2026, 2, 11)
    logs = MedicationLog.for_date(other_date)
    assert_empty logs
  end

  test "for_period scope returns logs within a date range" do
    start_date = Date.new(2026, 2, 9)
    end_date = Date.new(2026, 2, 11)
    logs = MedicationLog.for_period(start_date, end_date)
    assert_includes logs, medication_logs(:taken_log)
    assert_includes logs, medication_logs(:skipped_log)
  end

  test "for_period scope excludes logs outside range" do
    start_date = Date.new(2026, 2, 11)
    end_date = Date.new(2026, 2, 15)
    logs = MedicationLog.for_period(start_date, end_date)
    assert_empty logs
  end

  test "belongs_to medication" do
    log = medication_logs(:taken_log)
    assert_equal medications(:aspirin_morning), log.medication
  end

  test "belongs_to medication_schedule" do
    log = medication_logs(:taken_log)
    assert_equal medication_schedules(:morning_daily), log.medication_schedule
  end
end
