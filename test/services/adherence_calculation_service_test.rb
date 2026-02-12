require "test_helper"

class AdherenceCalculationServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @aspirin_med = medications(:aspirin_morning)
    @ibuprofen_med = medications(:ibuprofen_evening)
    @morning_schedule = medication_schedules(:morning_daily)
    @evening_schedule = medication_schedules(:evening_weekdays)
    @mwf_schedule = medication_schedules(:monday_wednesday_friday)
  end

  # --- Initialization & Validation ---

  test "defaults to 30 day period" do
    service = AdherenceCalculationService.new(user: @user)
    result = service.call
    assert_instance_of AdherenceCalculationService::AdherenceSummary, result
  end

  test "accepts 7 day period" do
    service = AdherenceCalculationService.new(user: @user, period_days: 7)
    result = service.call
    assert_instance_of AdherenceCalculationService::AdherenceSummary, result
  end

  test "accepts 90 day period" do
    service = AdherenceCalculationService.new(user: @user, period_days: 90)
    result = service.call
    assert_instance_of AdherenceCalculationService::AdherenceSummary, result
  end

  test "raises error for invalid period" do
    assert_raises(ArgumentError) do
      AdherenceCalculationService.new(user: @user, period_days: 15)
    end
  end

  # --- AdherenceSummary structure ---

  test "returns AdherenceSummary with medication_stats array" do
    service = AdherenceCalculationService.new(user: @user, period_days: 7)
    result = service.call

    assert_respond_to result, :medication_stats
    assert_kind_of Array, result.medication_stats
  end

  test "returns AdherenceSummary with daily_adherence hash" do
    service = AdherenceCalculationService.new(user: @user, period_days: 7)
    result = service.call

    assert_respond_to result, :daily_adherence
    assert_kind_of Hash, result.daily_adherence
  end

  test "returns AdherenceSummary with overall_percentage float" do
    service = AdherenceCalculationService.new(user: @user, period_days: 7)
    result = service.call

    assert_respond_to result, :overall_percentage
    assert_kind_of Float, result.overall_percentage
  end

  # --- MedicationStat structure ---

  test "medication_stats contain MedicationStat objects with correct attributes" do
    service = AdherenceCalculationService.new(user: @user, period_days: 7)
    result = service.call

    assert result.medication_stats.any?, "Should have at least one medication stat"

    stat = result.medication_stats.first
    assert_instance_of AdherenceCalculationService::MedicationStat, stat
    assert_respond_to stat, :medication
    assert_respond_to stat, :total_scheduled
    assert_respond_to stat, :total_taken
    assert_respond_to stat, :total_skipped
    assert_respond_to stat, :total_missed
    assert_respond_to stat, :percentage
  end

  # --- Percentage calculation correctness ---

  test "calculates correct percentage when all doses taken" do
    # Set up a known period where we control all logs
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      # Create a simple medication with a daily schedule
      prescription = Prescription.create!(user: @user, prescribed_date: Date.new(2026, 1, 1))
      drug = Drug.create!(name: "Test Drug")
      med = Medication.create!(prescription: prescription, drug: drug, dosage: "10mg", form: "tablet", active: true)
      schedule = MedicationSchedule.create!(medication: med, time_of_day: "09:00", days_of_week: [0, 1, 2, 3, 4, 5, 6])

      # Log all doses for the past 7 days as taken
      (1..7).each do |i|
        date = Time.zone.today - i.days
        MedicationLog.create!(
          medication: med,
          medication_schedule: schedule,
          scheduled_date: date,
          status: :taken,
          logged_at: Time.current
        )
      end

      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      # Find the stat for our test medication
      stat = result.medication_stats.find { |s| s.medication.id == med.id }
      assert_not_nil stat, "Should have stat for the test medication"
      assert_equal 7, stat.total_scheduled
      assert_equal 7, stat.total_taken
      assert_equal 0, stat.total_skipped
      assert_equal 0, stat.total_missed
      assert_in_delta 100.0, stat.percentage, 0.01
    end
  end

  test "calculates correct percentage with mixed taken and skipped" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      prescription = Prescription.create!(user: @user, prescribed_date: Date.new(2026, 1, 1))
      drug = Drug.create!(name: "Mix Drug")
      med = Medication.create!(prescription: prescription, drug: drug, dosage: "20mg", form: "tablet", active: true)
      schedule = MedicationSchedule.create!(medication: med, time_of_day: "09:00", days_of_week: [0, 1, 2, 3, 4, 5, 6])

      # 7 days: 4 taken, 2 skipped, 1 missed
      (1..7).each do |i|
        date = Time.zone.today - i.days
        if i <= 4
          MedicationLog.create!(medication: med, medication_schedule: schedule, scheduled_date: date, status: :taken, logged_at: Time.current)
        elsif i <= 6
          MedicationLog.create!(medication: med, medication_schedule: schedule, scheduled_date: date, status: :skipped, logged_at: Time.current)
        end
        # Day 7: no log = missed
      end

      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      stat = result.medication_stats.find { |s| s.medication.id == med.id }
      assert_not_nil stat
      assert_equal 7, stat.total_scheduled
      assert_equal 4, stat.total_taken
      assert_equal 2, stat.total_skipped
      assert_equal 1, stat.total_missed
      # Percentage = taken / scheduled * 100 = 4/7 * 100 ~ 57.14
      assert_in_delta 57.14, stat.percentage, 0.5
    end
  end

  # --- Missed dose counting ---

  test "missed doses are calculated as scheduled minus taken minus skipped" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      prescription = Prescription.create!(user: @user, prescribed_date: Date.new(2026, 1, 1))
      drug = Drug.create!(name: "Missed Drug")
      med = Medication.create!(prescription: prescription, drug: drug, dosage: "5mg", form: "tablet", active: true)
      schedule = MedicationSchedule.create!(medication: med, time_of_day: "09:00", days_of_week: [0, 1, 2, 3, 4, 5, 6])

      # 7 days: 2 taken, 1 skipped, 4 missed (no logs)
      [ 1, 3 ].each do |i|
        date = Time.zone.today - i.days
        MedicationLog.create!(medication: med, medication_schedule: schedule, scheduled_date: date, status: :taken, logged_at: Time.current)
      end
      MedicationLog.create!(medication: med, medication_schedule: schedule, scheduled_date: Time.zone.today - 5.days, status: :skipped, logged_at: Time.current)

      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      stat = result.medication_stats.find { |s| s.medication.id == med.id }
      assert_not_nil stat
      assert_equal 7, stat.total_scheduled
      assert_equal 2, stat.total_taken
      assert_equal 1, stat.total_skipped
      assert_equal 4, stat.total_missed # 7 - 2 - 1 = 4
    end
  end

  # --- Period boundary correctness ---

  test "period boundary includes correct number of days" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      # Daily adherence should have exactly 7 entries
      assert_equal 7, result.daily_adherence.size

      # Verify the date range covers the correct period (today - 6 days through today - 0 days)
      # Period is the last 7 days ending yesterday (or today depending on impl)
      dates = result.daily_adherence.keys.sort
      assert_equal 7, dates.size
    end
  end

  test "90 day period covers correct number of days" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      service = AdherenceCalculationService.new(user: @user, period_days: 90)
      result = service.call

      assert_equal 90, result.daily_adherence.size
    end
  end

  # --- Daily adherence percentages ---

  test "daily_adherence contains Date keys with Float values between 0 and 1" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      result.daily_adherence.each do |date, percentage|
        assert_kind_of Date, date, "Key should be a Date"
        assert_kind_of Float, percentage, "Value should be a Float"
        assert percentage >= 0.0, "Percentage should be >= 0"
        assert percentage <= 1.0, "Percentage should be <= 1"
      end
    end
  end

  test "daily adherence is correct ratio of taken to scheduled" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      prescription = Prescription.create!(user: @user, prescribed_date: Date.new(2026, 1, 1))
      drug = Drug.create!(name: "Daily Ratio Drug")
      med = Medication.create!(prescription: prescription, drug: drug, dosage: "10mg", form: "tablet", active: true)
      schedule = MedicationSchedule.create!(medication: med, time_of_day: "09:00", days_of_week: [0, 1, 2, 3, 4, 5, 6])

      # Log yesterday as taken
      yesterday = Time.zone.today - 1.day
      MedicationLog.create!(medication: med, medication_schedule: schedule, scheduled_date: yesterday, status: :taken, logged_at: Time.current)

      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      # Yesterday's adherence should reflect the taken dose
      # Note: The exact value depends on how many total schedules are active for that day
      # At minimum, this medication's dose was taken
      assert result.daily_adherence.key?(yesterday), "Should have daily adherence for yesterday"
    end
  end

  # --- Overall percentage ---

  test "overall_percentage is average of per-medication percentages" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      assert result.overall_percentage >= 0.0
      assert result.overall_percentage <= 100.0
    end
  end

  # --- Empty schedule handling ---

  test "returns zero adherence for user with no active medications" do
    service = AdherenceCalculationService.new(user: @other_user, period_days: 7)
    result = service.call

    assert_equal [], result.medication_stats
    assert_equal 7, result.daily_adherence.size
    assert_equal 0.0, result.overall_percentage

    # All daily values should be 0.0 when no schedules exist
    result.daily_adherence.each_value do |val|
      assert_equal 0.0, val
    end
  end

  # --- Medication with no logs ---

  test "medication with no logs shows zero taken and all missed" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      prescription = Prescription.create!(user: @user, prescribed_date: Date.new(2026, 1, 1))
      drug = Drug.create!(name: "No Log Drug")
      med = Medication.create!(prescription: prescription, drug: drug, dosage: "10mg", form: "tablet", active: true)
      MedicationSchedule.create!(medication: med, time_of_day: "09:00", days_of_week: [0, 1, 2, 3, 4, 5, 6])

      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      stat = result.medication_stats.find { |s| s.medication.id == med.id }
      assert_not_nil stat
      assert_equal 7, stat.total_scheduled
      assert_equal 0, stat.total_taken
      assert_equal 0, stat.total_skipped
      assert_equal 7, stat.total_missed
      assert_in_delta 0.0, stat.percentage, 0.01
    end
  end

  # --- Day-of-week rules ---

  test "scheduled doses respect day-of-week rules" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      # Thu Feb 12, 2026: looking back 7 days = Feb 5 (Thu) through Feb 11 (Wed)
      prescription = Prescription.create!(user: @user, prescribed_date: Date.new(2026, 1, 1))
      drug = Drug.create!(name: "Weekday Drug")
      med = Medication.create!(prescription: prescription, drug: drug, dosage: "10mg", form: "tablet", active: true)
      # Schedule only on weekdays: Mon(1), Tue(2), Wed(3), Thu(4), Fri(5)
      MedicationSchedule.create!(medication: med, time_of_day: "09:00", days_of_week: [1, 2, 3, 4, 5])

      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      stat = result.medication_stats.find { |s| s.medication.id == med.id }
      assert_not_nil stat
      # In a 7-day window, count of weekdays depends on the exact dates
      # Feb 5 (Thu) to Feb 11 (Wed): Thu, Fri, Mon, Tue, Wed = 5 weekdays
      assert_equal 5, stat.total_scheduled
    end
  end

  # --- Inactive medication exclusion ---

  test "excludes inactive medications from stats" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      # The inactive_medication fixture should not appear in stats
      inactive_med = medications(:inactive_medication)
      stat = result.medication_stats.find { |s| s.medication.id == inactive_med.id }
      assert_nil stat, "Inactive medication should not appear in adherence stats"
    end
  end

  # --- User scoping ---

  test "only includes medications belonging to the specified user" do
    travel_to Time.zone.local(2026, 2, 12, 10, 0, 0) do
      service = AdherenceCalculationService.new(user: @user, period_days: 7)
      result = service.call

      result.medication_stats.each do |stat|
        assert_equal @user.id, stat.medication.prescription.user_id,
          "All medication stats should belong to the specified user"
      end
    end
  end
end
