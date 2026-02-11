class MedicationSchedulesController < ApplicationController
  before_action :set_medication, only: %i[new create]
  before_action :set_medication_schedule, only: %i[edit update destroy]

  def new
    @medication_schedule = @medication.medication_schedules.build
  end

  def create
    @medication_schedule = @medication.medication_schedules.build(medication_schedule_params)

    if @medication_schedule.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @medication.prescription, notice: "Schedule was successfully added." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @medication_schedule.update(medication_schedule_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @medication_schedule.medication.prescription, notice: "Schedule was successfully updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @medication = @medication_schedule.medication
    @medication_schedule.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @medication.prescription, notice: "Schedule was successfully removed." }
    end
  end

  private

  def set_medication
    @medication = Medication.joins(:prescription)
      .where(prescriptions: { user_id: Current.user.id })
      .find(params[:medication_id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def set_medication_schedule
    @medication_schedule = MedicationSchedule.joins(medication: :prescription)
      .where(prescriptions: { user_id: Current.user.id })
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def medication_schedule_params
    params.require(:medication_schedule).permit(:time_of_day, :dosage_amount, :instructions, days_of_week: [])
  end
end
