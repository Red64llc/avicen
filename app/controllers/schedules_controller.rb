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
end
