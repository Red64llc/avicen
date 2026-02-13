class BiologyReportsController < ApplicationController
  before_action :set_biology_report, only: [ :show, :edit, :update, :destroy ]

  # GET /biology_reports
  def index
    @biology_reports = Current.user.biology_reports.ordered

    # Apply filters
    @biology_reports = @biology_reports.by_date_range(params[:date_from], params[:date_to]) if params[:date_from].present? || params[:date_to].present?
    @biology_reports = @biology_reports.by_lab_name(params[:lab_name]) if params[:lab_name].present?
  end

  # GET /biology_reports/:id
  def show
  end

  # GET /biology_reports/new
  def new
    @biology_report = BiologyReport.new
  end

  # POST /biology_reports
  def create
    @biology_report = Current.user.biology_reports.build(biology_report_params)

    if @biology_report.save
      redirect_to @biology_report, notice: "Biology report was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /biology_reports/:id/edit
  def edit
  end

  # PATCH/PUT /biology_reports/:id
  def update
    if @biology_report.update(biology_report_params)
      redirect_to @biology_report, notice: "Biology report was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /biology_reports/:id
  def destroy
    @biology_report.destroy
    redirect_to biology_reports_url, notice: "Biology report was successfully deleted."
  end

  private

  def set_biology_report
    @biology_report = Current.user.biology_reports.includes(test_results: :biomarker).find(params.expect(:id))
  end

  def biology_report_params
    params.expect(biology_report: [ :test_date, :lab_name, :notes, :document ])
  end
end
