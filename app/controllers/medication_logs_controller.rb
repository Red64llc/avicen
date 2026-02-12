class MedicationLogsController < ApplicationController
  before_action :set_schedule_and_validate_ownership, only: :create
  before_action :set_medication_log, only: :destroy

  # POST /medication_logs
  # Idempotent upsert: find_or_initialize_by(medication_schedule_id, scheduled_date)
  def create
    @medication_log = MedicationLog.find_or_initialize_by(
      medication_schedule_id: medication_log_params[:medication_schedule_id],
      scheduled_date: medication_log_params[:scheduled_date]
    )

    @medication_log.assign_attributes(
      medication_id: medication_log_params[:medication_id],
      status: medication_log_params[:status],
      reason: medication_log_params[:reason],
      logged_at: Time.current
    )

    if @medication_log.save
      @entry = build_schedule_entry(@medication_log)
      @date = @medication_log.scheduled_date
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to schedule_path(date: @medication_log.scheduled_date) }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to schedule_path, alert: "Could not log medication." }
      end
    end
  end

  # DELETE /medication_logs/:id
  # Undo: destroy the log, returning the entry to pending state
  def destroy
    @schedule = @medication_log.medication_schedule
    @scheduled_date = @medication_log.scheduled_date
    @medication_log.destroy!

    @entry = build_pending_entry(@schedule, @scheduled_date)
    @date = @scheduled_date
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to schedule_path(date: @scheduled_date) }
    end
  end

  private

  def medication_log_params
    params.require(:medication_log).permit(
      :medication_id,
      :medication_schedule_id,
      :scheduled_date,
      :status,
      :reason
    )
  end

  # Verify the schedule belongs to the current user through the prescription chain
  def set_schedule_and_validate_ownership
    schedule = MedicationSchedule
      .joins(medication: { prescription: :user })
      .where(prescriptions: { user_id: Current.user.id })
      .find_by(id: medication_log_params[:medication_schedule_id])

    head :not_found unless schedule
  end

  # Verify the log belongs to the current user through the prescription chain
  def set_medication_log
    @medication_log = MedicationLog
      .joins(medication: { prescription: :user })
      .where(prescriptions: { user_id: Current.user.id })
      .includes(medication: [ :drug, :prescription ], medication_schedule: :medication)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  # Build a ScheduleEntry for Turbo Stream rendering after create
  def build_schedule_entry(log)
    medication = log.medication
    schedule = log.medication_schedule
    status = log.taken? ? :taken : :skipped
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
      overdue: false
    )
  end

  # Build a pending ScheduleEntry for Turbo Stream rendering after destroy (undo)
  def build_pending_entry(schedule, scheduled_date)
    medication = schedule.medication

    # Check overdue status for the pending entry
    overdue = determine_overdue(schedule, scheduled_date)
    dosage = schedule.dosage_amount.presence || medication.dosage

    DailyScheduleQuery::ScheduleEntry.new(
      medication: medication,
      schedule: schedule,
      drug_name: medication.drug.name,
      dosage: dosage,
      form: medication.form,
      instructions: schedule.instructions,
      status: :pending,
      log: nil,
      overdue: overdue
    )
  end

  def determine_overdue(schedule, scheduled_date)
    today = Time.zone.today
    if scheduled_date > today
      false
    elsif scheduled_date < today
      true
    else
      now = Time.zone.now
      hour, minute = schedule.time_of_day.split(":").map(&:to_i)
      scheduled_time = Time.zone.local(scheduled_date.year, scheduled_date.month, scheduled_date.day, hour, minute)
      now > scheduled_time
    end
  end
end
