class SchedulesController < ApplicationController
  # GET /schedule
  # GET /schedule?date=YYYY-MM-DD
  def show
    @date = parse_date_param
    @grouped_entries = DailyScheduleQuery.new(user: Current.user, date: @date).call
    @previous_date = @date - 1.day
    @next_date = @date + 1.day
  end

  # GET /schedule/weekly
  # GET /schedule/weekly?week_start=YYYY-MM-DD
  def weekly
    @week_start = parse_week_start_param
    @day_summaries = WeeklyScheduleQuery.new(user: Current.user, week_start: @week_start).call
    @previous_week_start = @week_start - 7.days
    @next_week_start = @week_start + 7.days
  end

  # GET /schedule/print
  def print
    @medications = fetch_active_medications_with_schedules
    @time_groups = group_schedules_by_time_of_day(@medications)
    @generated_at = Time.zone.now
  end

  private

  def parse_date_param
    if params[:date].present?
      Date.parse(params[:date])
    else
      Time.zone.today
    end
  rescue Date::Error
    Time.zone.today
  end

  def parse_week_start_param
    if params[:week_start].present?
      Date.parse(params[:week_start]).beginning_of_week(:monday)
    else
      Time.zone.today.beginning_of_week(:monday)
    end
  rescue Date::Error
    Time.zone.today.beginning_of_week(:monday)
  end

  # Fetch all active medications for the current user with their schedules and drug data
  def fetch_active_medications_with_schedules
    Medication
      .joins(:prescription)
      .where(prescriptions: { user_id: Current.user.id })
      .where(active: true)
      .includes(:drug, medication_schedules: [])
      .to_a
  end

  # Group all schedules across active medications into time-of-day groups.
  # Time-of-day groups: morning (before 12:00), midday (12:00-16:59),
  # evening (17:00-20:59), night (21:00+)
  #
  # @return [Hash{String => Array<Hash>}] Schedules organized by time-of-day group
  def group_schedules_by_time_of_day(medications)
    groups = {
      "Morning" => [],
      "Midday" => [],
      "Evening" => [],
      "Night" => []
    }

    medications.each do |medication|
      medication.medication_schedules.ordered_by_time.each do |schedule|
        group_name = time_of_day_group(schedule.time_of_day)
        groups[group_name] << {
          medication: medication,
          schedule: schedule,
          drug_name: medication.drug.name,
          dosage: schedule.dosage_amount.presence || medication.dosage,
          form: medication.form,
          instructions: schedule.instructions,
          days_of_week_names: schedule.days_of_week_names,
          time_of_day: schedule.time_of_day
        }
      end
    end

    # Remove empty groups
    groups.reject { |_k, v| v.empty? }
  end

  # Classify a time_of_day string (HH:MM) into a time-of-day group
  def time_of_day_group(time_str)
    hour = time_str.split(":").first.to_i
    if hour < 12
      "Morning"
    elsif hour < 17
      "Midday"
    elsif hour < 21
      "Evening"
    else
      "Night"
    end
  end
end
