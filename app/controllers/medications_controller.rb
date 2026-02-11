class MedicationsController < ApplicationController
  before_action :set_prescription, only: %i[new create]
  before_action :set_medication, only: %i[edit update destroy toggle]

  def new
    @medication = @prescription.medications.build
  end

  def create
    @medication = @prescription.medications.build(medication_params)

    if @medication.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @prescription, notice: "Medication was successfully added." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @medication.update(medication_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @medication.prescription, notice: "Medication was successfully updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @prescription = @medication.prescription
    @medication.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @prescription, notice: "Medication was successfully removed." }
    end
  end

  def toggle
    @medication.update!(active: !@medication.active?)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @medication.prescription }
    end
  end

  private

  def set_prescription
    @prescription = Current.user.prescriptions.find(params[:prescription_id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def set_medication
    @medication = Medication.joins(:prescription).includes(:drug, :medication_schedules)
      .where(prescriptions: { user_id: Current.user.id })
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def medication_params
    params.require(:medication).permit(:drug_id, :dosage, :form, :instructions, :active)
  end
end
