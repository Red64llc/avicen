# Compute the weekly medication schedule overview with per-day adherence summaries.
#
# Fetches all schedules and logs for the 7-day span in bulk queries,
# then computes daily entries using the same logic as DailyScheduleQuery
# to maintain consistency while avoiding N+1 queries.
#
# @example
#   result = WeeklyScheduleQuery.new(user: Current.user, week_start: Date.today.beginning_of_week(:monday)).call
#   result.each do |day_summary|
#     puts "#{day_summary.date}: #{day_summary.adherence_status} (#{day_summary.total_logged}/#{day_summary.total_scheduled})"
#   end
class WeeklyScheduleQuery
  DaySummary = Data.define(
    :date,               # Date
    :entries,            # Array<DailyScheduleQuery::ScheduleEntry>
    :total_scheduled,    # Integer
    :total_logged,       # Integer
    :adherence_status    # Symbol (:complete, :partial, :none, :empty)
  )

  # @param user [User]
  # @param week_start [Date] Monday of the target week (snaps to Monday if not)
  def initialize(user:, week_start: nil)
    @user = user
    @week_start = normalize_week_start(week_start)
  end

  # @return [Array<DaySummary>] Seven DaySummary objects (Mon-Sun)
  def call
    all_schedules = fetch_all_schedules
    all_logs = fetch_all_logs(all_schedules)
    logs_by_schedule_and_date = index_logs(all_logs)
    schedules_by_wday = group_schedules_by_wday(all_schedules)

    week_dates.map do |date|
      day_schedules = schedules_by_wday.fetch(date.wday, [])

      entries = day_schedules.map do |schedule|
        log = logs_by_schedule_and_date[[ schedule.id, date ]]
        build_entry(schedule.medication, schedule, log, date)
      end.sort_by { |e| e.schedule.time_of_day }

      total_scheduled = entries.size
      total_logged = entries.count { |e| e.status != :pending }

      DaySummary.new(
        date: date,
        entries: entries,
        total_scheduled: total_scheduled,
        total_logged: total_logged,
        adherence_status: compute_adherence_status(total_scheduled, total_logged)
      )
    end
  end

  private

  attr_reader :user, :week_start

  def normalize_week_start(date)
    date = date || Time.zone.today
    date.beginning_of_week(:monday)
  end

  def week_dates
    (0..6).map { |i| week_start + i.days }
  end

  def fetch_all_schedules
    # Collect unique wday values for the week (always 0-6 for a full week)
    wdays = week_dates.map(&:wday).uniq

    MedicationSchedule
      .joins(medication: { prescription: :user })
      .where(prescriptions: { user_id: user.id })
      .where(medications: { active: true })
      .where(
        wdays.map { "EXISTS (SELECT 1 FROM json_each(medication_schedules.days_of_week) WHERE json_each.value = ?)" }.join(" OR "),
        *wdays
      )
      .includes(medication: [ :drug, :prescription ])
      .ordered_by_time
      .to_a
  end

  def fetch_all_logs(schedules)
    return [] if schedules.empty?

    MedicationLog
      .where(medication_schedule_id: schedules.map(&:id))
      .for_period(week_start, week_start + 6.days)
      .to_a
  end

  def index_logs(logs)
    logs.index_by { |log| [ log.medication_schedule_id, log.scheduled_date ] }
  end

  def group_schedules_by_wday(schedules)
    result = Hash.new { |h, k| h[k] = [] }
    schedules.each do |schedule|
      days = schedule.days_of_week
      days.each do |wday|
        result[wday] << schedule
      end
    end
    result
  end

  def build_entry(medication, schedule, log, date)
    status = determine_status(log)
    dosage = schedule.dosage_amount.presence || medication.dosage

    DailyScheduleQuery::ScheduleEntry.new(
      medication: medication,
      schedule: schedule,
      drug_name: medication.drug.name,
      dosage: dosage,
      form: medication.form,
      instructions: schedule.instructions,
      status: status,
      log: log,
      overdue: determine_overdue(schedule, status, date)
    )
  end

  def determine_status(log)
    return :pending if log.nil?
    log.taken? ? :taken : :skipped
  end

  def determine_overdue(schedule, status, date)
    return false unless status == :pending

    today = Time.zone.today
    if date > today
      false
    elsif date < today
      true
    else
      now = Time.zone.now
      hour, minute = schedule.time_of_day.split(":").map(&:to_i)
      scheduled_time = Time.zone.local(date.year, date.month, date.day, hour, minute)
      now > scheduled_time
    end
  end

  def compute_adherence_status(total_scheduled, total_logged)
    if total_scheduled == 0
      :empty
    elsif total_logged == 0
      :none
    elsif total_logged >= total_scheduled
      :complete
    else
      :partial
    end
  end
end
