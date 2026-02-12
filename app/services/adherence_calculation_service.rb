# Calculate adherence statistics for a user's medications over a configurable period.
#
# Computes per-medication adherence (total scheduled, taken, skipped, missed)
# and daily adherence percentages for calendar heatmap visualization.
#
# @example
#   result = AdherenceCalculationService.new(user: Current.user, period_days: 30).call
#   result.medication_stats.each { |s| puts "#{s.medication.drug.name}: #{s.percentage}%" }
#   result.daily_adherence.each { |date, ratio| puts "#{date}: #{(ratio * 100).round}%" }
class AdherenceCalculationService
  VALID_PERIODS = [ 7, 30, 90 ].freeze

  AdherenceSummary = Data.define(
    :medication_stats,   # Array<MedicationStat>
    :daily_adherence,    # Hash { Date => Float(0.0..1.0) }
    :overall_percentage  # Float (0.0..100.0)
  )

  MedicationStat = Data.define(
    :medication,         # Medication record
    :total_scheduled,    # Integer
    :total_taken,        # Integer
    :total_skipped,      # Integer
    :total_missed,       # Integer
    :percentage          # Float (0.0..100.0)
  )

  # @param user [User] The authenticated user
  # @param period_days [Integer] Number of days to analyze (7, 30, or 90)
  # @raise [ArgumentError] if period_days is not one of [7, 30, 90]
  def initialize(user:, period_days: 30)
    unless VALID_PERIODS.include?(period_days)
      raise ArgumentError, "period_days must be one of #{VALID_PERIODS.inspect}, got #{period_days}"
    end

    @user = user
    @period_days = period_days
  end

  # @return [AdherenceSummary] Structured adherence data
  def call
    medications = fetch_active_medications
    schedules = fetch_schedules(medications)
    logs = fetch_logs(schedules)

    date_range = compute_date_range
    logs_index = index_logs(logs)
    schedules_by_medication = schedules.group_by(&:medication_id)

    medication_stats = compute_medication_stats(medications, schedules_by_medication, logs_index, date_range)
    daily_adherence = compute_daily_adherence(schedules, logs_index, date_range)
    overall_percentage = compute_overall_percentage(medication_stats)

    AdherenceSummary.new(
      medication_stats: medication_stats,
      daily_adherence: daily_adherence,
      overall_percentage: overall_percentage
    )
  end

  private

  attr_reader :user, :period_days

  def compute_date_range
    end_date = Time.zone.today - 1.day
    start_date = end_date - (period_days - 1).days
    (start_date..end_date).to_a
  end

  def fetch_active_medications
    Medication
      .joins(:prescription)
      .where(prescriptions: { user_id: user.id })
      .where(active: true)
      .includes(:drug, :prescription, :medication_schedules)
      .to_a
  end

  def fetch_schedules(medications)
    return [] if medications.empty?

    MedicationSchedule
      .where(medication_id: medications.map(&:id))
      .includes(:medication)
      .to_a
  end

  def fetch_logs(schedules)
    return [] if schedules.empty?

    date_range = compute_date_range
    start_date = date_range.first
    end_date = date_range.last

    MedicationLog
      .where(medication_schedule_id: schedules.map(&:id))
      .for_period(start_date, end_date)
      .to_a
  end

  # Index logs by [medication_schedule_id, scheduled_date] for O(1) lookup
  def index_logs(logs)
    logs.index_by { |log| [ log.medication_schedule_id, log.scheduled_date ] }
  end

  def compute_medication_stats(medications, schedules_by_medication, logs_index, date_range)
    medications.filter_map do |medication|
      med_schedules = schedules_by_medication.fetch(medication.id, [])
      next if med_schedules.empty?

      total_scheduled = 0
      total_taken = 0
      total_skipped = 0

      date_range.each do |date|
        wday = date.wday
        med_schedules.each do |schedule|
          next unless schedule_applies_on_day?(schedule, wday)

          total_scheduled += 1
          log = logs_index[[ schedule.id, date ]]
          if log
            if log.taken?
              total_taken += 1
            elsif log.skipped?
              total_skipped += 1
            end
          end
        end
      end

      total_missed = total_scheduled - total_taken - total_skipped
      percentage = total_scheduled > 0 ? (total_taken.to_f / total_scheduled * 100.0) : 0.0

      MedicationStat.new(
        medication: medication,
        total_scheduled: total_scheduled,
        total_taken: total_taken,
        total_skipped: total_skipped,
        total_missed: total_missed,
        percentage: percentage.round(2)
      )
    end
  end

  def compute_daily_adherence(schedules, logs_index, date_range)
    daily = {}

    date_range.each do |date|
      wday = date.wday
      day_scheduled = 0
      day_taken = 0

      schedules.each do |schedule|
        next unless schedule_applies_on_day?(schedule, wday)

        day_scheduled += 1
        log = logs_index[[ schedule.id, date ]]
        day_taken += 1 if log&.taken?
      end

      daily[date] = day_scheduled > 0 ? (day_taken.to_f / day_scheduled) : 0.0
    end

    daily
  end

  def compute_overall_percentage(medication_stats)
    return 0.0 if medication_stats.empty?

    total_scheduled = medication_stats.sum(&:total_scheduled)
    total_taken = medication_stats.sum(&:total_taken)

    total_scheduled > 0 ? (total_taken.to_f / total_scheduled * 100.0).round(2) : 0.0
  end

  def schedule_applies_on_day?(schedule, wday)
    days = schedule.days_of_week
    return false unless days.is_a?(Array)
    days.include?(wday)
  end
end
