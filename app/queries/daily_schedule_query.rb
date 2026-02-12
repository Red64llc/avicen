# Compute the complete daily medication schedule for a user on a given date.
#
# Fetches active medications through user prescriptions, filters schedules
# by day of week, joins with medication logs for status, groups by time_of_day,
# and detects overdue entries.
#
# @example
#   result = DailyScheduleQuery.new(user: Current.user, date: Date.today).call
#   result.each do |time_of_day, entries|
#     entries.each { |entry| puts "#{entry.drug_name} #{entry.dosage} - #{entry.status}" }
#   end
class DailyScheduleQuery
  ScheduleEntry = Data.define(
    :medication,     # Medication record
    :schedule,       # MedicationSchedule record
    :drug_name,      # String
    :dosage,         # String (schedule-specific or medication default)
    :form,           # String
    :instructions,   # String (schedule instructions)
    :status,         # Symbol (:pending, :taken, :skipped)
    :log,            # MedicationLog or nil
    :overdue         # Boolean
  )

  # @param user [User]
  # @param date [Date] Target date (defaults to today in user's timezone)
  def initialize(user:, date: nil)
    @user = user
    @date = date || Time.zone.today
  end

  # @return [Hash{String => Array<ScheduleEntry>}] Entries grouped by time_of_day, sorted chronologically
  def call
    schedules = fetch_schedules
    logs = fetch_logs(schedules)
    logs_by_schedule_id = logs.index_by(&:medication_schedule_id)

    entries = schedules.map do |schedule|
      medication = schedule.medication
      log = logs_by_schedule_id[schedule.id]

      build_entry(medication, schedule, log)
    end

    entries
      .sort_by { |e| e.schedule.time_of_day }
      .group_by { |e| e.schedule.time_of_day }
  end

  private

  attr_reader :user, :date

  def fetch_schedules
    MedicationSchedule
      .joins(medication: { prescription: :user })
      .where(prescriptions: { user_id: user.id })
      .where(medications: { active: true })
      .for_day(date.wday)
      .ordered_by_time
      .includes(medication: [ :drug, :prescription ])
      .to_a
  end

  def fetch_logs(schedules)
    return [] if schedules.empty?

    MedicationLog
      .where(medication_schedule_id: schedules.map(&:id))
      .for_date(date)
      .to_a
  end

  def build_entry(medication, schedule, log)
    status = determine_status(log)
    overdue = determine_overdue(schedule, status)
    dosage = schedule.dosage_amount.presence || medication.dosage

    ScheduleEntry.new(
      medication: medication,
      schedule: schedule,
      drug_name: medication.drug.name,
      dosage: dosage,
      form: medication.form,
      instructions: schedule.instructions,
      status: status,
      log: log,
      overdue: overdue
    )
  end

  def determine_status(log)
    return :pending if log.nil?

    log.taken? ? :taken : :skipped
  end

  def determine_overdue(schedule, status)
    return false unless status == :pending

    # Only consider overdue if the date is today or in the past
    today = Time.zone.today
    if date > today
      false
    elsif date < today
      # Past date with pending status -- the scheduled time has definitively passed
      true
    else
      # Today: check if the scheduled time has passed
      now = Time.zone.now
      hour, minute = schedule.time_of_day.split(":").map(&:to_i)
      scheduled_time = Time.zone.local(date.year, date.month, date.day, hour, minute)
      now > scheduled_time
    end
  end
end
