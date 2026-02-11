require "test_helper"

class MedicationScheduleTest < ActiveSupport::TestCase
  test "validates time_of_day presence" do
    schedule = MedicationSchedule.new(
      medication: medications(:aspirin_morning),
      time_of_day: nil,
      days_of_week: [ 1, 2, 3 ]
    )
    assert_not schedule.valid?
    assert_includes schedule.errors[:time_of_day], "can't be blank"
  end

  test "validates days_of_week presence" do
    schedule = MedicationSchedule.new(
      medication: medications(:aspirin_morning),
      time_of_day: "08:00",
      days_of_week: nil
    )
    assert_not schedule.valid?
    assert_includes schedule.errors[:days_of_week], "can't be blank"
  end

  test "validates at least one day selected" do
    schedule = MedicationSchedule.new(
      medication: medications(:aspirin_morning),
      time_of_day: "08:00",
      days_of_week: []
    )
    assert_not schedule.valid?
    assert_includes schedule.errors[:days_of_week], "must have at least one day selected"
  end

  test "valid with all required attributes" do
    schedule = MedicationSchedule.new(
      medication: medications(:aspirin_morning),
      time_of_day: "08:00",
      days_of_week: [ 1, 3, 5 ]
    )
    assert schedule.valid?
  end

  test "belongs_to medication" do
    schedule = medication_schedules(:morning_daily)
    assert_equal medications(:aspirin_morning), schedule.medication
  end

  test "has_many medication_logs with dependent destroy" do
    schedule = medication_schedules(:morning_daily)
    assert_respond_to schedule, :medication_logs
    assert_equal :destroy, MedicationSchedule.reflect_on_association(:medication_logs).options[:dependent]
  end

  test "JSON serialization round-trip for days_of_week" do
    schedule = MedicationSchedule.create!(
      medication: medications(:aspirin_morning),
      time_of_day: "09:00",
      days_of_week: [ 0, 2, 4, 6 ]
    )
    schedule.reload
    assert_equal [ 0, 2, 4, 6 ], schedule.days_of_week
  end

  test "for_day scope filters schedules for a specific day" do
    # Monday = 1
    monday_schedules = MedicationSchedule.for_day(1)
    assert_includes monday_schedules, medication_schedules(:morning_daily)
    assert_includes monday_schedules, medication_schedules(:evening_weekdays)
    assert_includes monday_schedules, medication_schedules(:monday_wednesday_friday)
  end

  test "for_day scope excludes schedules not for that day" do
    # Saturday = 6
    saturday_schedules = MedicationSchedule.for_day(6)
    assert_includes saturday_schedules, medication_schedules(:morning_daily)
    assert_not_includes saturday_schedules, medication_schedules(:evening_weekdays)
    assert_not_includes saturday_schedules, medication_schedules(:monday_wednesday_friday)
  end

  test "ordered_by_time scope orders by time_of_day ascending" do
    schedules = MedicationSchedule.ordered_by_time
    times = schedules.pluck(:time_of_day)
    assert_equal times, times.sort
  end
end
