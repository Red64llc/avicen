class AdherenceController < ApplicationController
  VALID_PERIODS = [ 7, 30, 90 ].freeze

  # GET /adherence
  # GET /adherence?period=7|30|90&date=YYYY-MM-DD
  def index
    @period = parse_period_param
    @summary = AdherenceCalculationService.new(user: Current.user, period_days: @period).call
    @selected_date = parse_date_param
    @date_logs = fetch_date_logs if @selected_date
  end

  private

  def parse_period_param
    period = params[:period].to_i
    VALID_PERIODS.include?(period) ? period : 30
  end

  def parse_date_param
    return nil unless params[:date].present?
    Date.parse(params[:date])
  rescue Date::Error
    nil
  end

  def fetch_date_logs
    MedicationLog
      .joins(medication: { prescription: :user })
      .where(prescriptions: { user_id: Current.user.id })
      .where(scheduled_date: @selected_date)
      .includes(medication: :drug, medication_schedule: :medication)
      .order(:logged_at)
      .to_a
  end
end
