class SchedulesController < ApplicationController
  # GET /schedule
  # GET /schedule?date=YYYY-MM-DD
  def show
    @date = parse_date_param
    @grouped_entries = DailyScheduleQuery.new(user: Current.user, date: @date).call
    @previous_date = @date - 1.day
    @next_date = @date + 1.day
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
end
