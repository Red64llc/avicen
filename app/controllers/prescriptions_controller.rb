class PrescriptionsController < ApplicationController
  before_action :set_prescription, only: %i[show edit update destroy]

  def index
    @prescriptions = Current.user.prescriptions
      .ordered
      .includes(medications: :drug)
  end

  def show
  end

  def new
    @prescription = Current.user.prescriptions.build
  end

  def create
    @prescription = Current.user.prescriptions.build(prescription_params)

    if @prescription.save
      redirect_to @prescription, notice: "Prescription was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @prescription.update(prescription_params)
      redirect_to @prescription, notice: "Prescription was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @prescription.destroy!
    redirect_to prescriptions_path, notice: "Prescription was successfully deleted."
  end

  private

  def set_prescription
    @prescription = Current.user.prescriptions.includes(medications: :drug).find(params[:id])
  end

  def prescription_params
    params.require(:prescription).permit(:doctor_name, :prescribed_date, :notes)
  end
end
