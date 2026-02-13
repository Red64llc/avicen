class TestResultsController < ApplicationController
  before_action :set_biology_report
  before_action :set_test_result, only: [ :edit, :update, :destroy ]

  # GET /biology_reports/:biology_report_id/test_results/new
  def new
    @test_result = @biology_report.test_results.build
    @biomarker = Biomarker.find_by(id: params[:biomarker_id]) if params[:biomarker_id].present?

    # Auto-fill reference ranges from biomarker if provided
    if @biomarker
      @test_result.unit = @biomarker.unit
      @test_result.ref_min = @biomarker.ref_min
      @test_result.ref_max = @biomarker.ref_max
    end
  end

  # POST /biology_reports/:biology_report_id/test_results
  def create
    @test_result = @biology_report.test_results.build(test_result_params)

    respond_to do |format|
      if @test_result.save
        format.turbo_stream
        format.html { redirect_to @biology_report, notice: "Test result was successfully created." }
      else
        format.turbo_stream { render :form_update, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # GET /biology_reports/:biology_report_id/test_results/:id/edit
  def edit
  end

  # PATCH/PUT /biology_reports/:biology_report_id/test_results/:id
  def update
    respond_to do |format|
      if @test_result.update(test_result_params)
        format.turbo_stream
        format.html { redirect_to @biology_report, notice: "Test result was successfully updated." }
      else
        format.turbo_stream { render :form_update, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /biology_reports/:biology_report_id/test_results/:id
  def destroy
    @test_result.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @biology_report, notice: "Test result was successfully deleted." }
    end
  end

  private

  def set_biology_report
    # Scope through Current.user to ensure user can only access their own biology reports
    @biology_report = Current.user.biology_reports.find(params[:biology_report_id])
  end

  def set_test_result
    # Scope through parent biology_report to ensure user ownership
    @test_result = @biology_report.test_results.find(params[:id])
  end

  def test_result_params
    params.require(:test_result).permit(:biomarker_id, :value, :unit, :ref_min, :ref_max)
  end
end
