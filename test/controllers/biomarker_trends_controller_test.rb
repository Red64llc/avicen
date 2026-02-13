require "test_helper"

class BiomarkerTrendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)

    @biomarker = biomarkers(:glucose)
    @biology_report1 = biology_reports(:one)
    @biology_report2 = biology_reports(:two)
  end

  test "show returns 200 when biomarker has sufficient data" do
    create_test_results(2)
    
    get biomarker_trends_path(@biomarker)
    
    assert_response :success
    assert_not_nil assigns(:biomarker)
    assert_not_nil assigns(:chart_data)
  end

  test "show renders table view when fewer than 2 data points" do
    create_test_results(1)
    
    get biomarker_trends_path(@biomarker)
    
    assert_response :success
    assert assigns(:insufficient_data)
  end

  test "show returns 404 when biomarker not found" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get biomarker_trends_path(id: 99999)
    end
  end

  test "show returns 404 when no data exists for user" do
    # No test results for this biomarker
    get biomarker_trends_path(@biomarker)
    
    assert_response :not_found
  end

  test "show scopes test results to current user" do
    other_user = users(:two)
    other_report = BiologyReport.create!(
      user: other_user,
      test_date: Date.today,
      lab_name: "Other Lab"
    )
    
    # Create test results for both users
    TestResult.create!(
      biology_report: @biology_report1,
      biomarker: @biomarker,
      value: 95,
      unit: "mg/dL",
      ref_min: 70,
      ref_max: 100
    )
    
    TestResult.create!(
      biology_report: other_report,
      biomarker: @biomarker,
      value: 110,
      unit: "mg/dL",
      ref_min: 70,
      ref_max: 100
    )
    
    get biomarker_trends_path(@biomarker)
    
    # Should only have 1 data point (current user's), so insufficient data
    assert assigns(:insufficient_data)
  end

  test "chart data includes test dates as labels" do
    create_test_results(2)
    
    get biomarker_trends_path(@biomarker)
    
    chart_data = assigns(:chart_data)
    assert chart_data[:labels].present?
    assert_equal 2, chart_data[:labels].size
  end

  test "chart data includes values in datasets" do
    create_test_results(2)
    
    get biomarker_trends_path(@biomarker)
    
    chart_data = assigns(:chart_data)
    assert chart_data[:datasets].present?
    assert_equal 2, chart_data[:datasets].first[:data].size
  end

  test "chart data includes reference range annotations" do
    create_test_results(2)
    
    get biomarker_trends_path(@biomarker)
    
    chart_data = assigns(:chart_data)
    assert chart_data[:annotations].present?
    assert chart_data[:annotations][:normalRange].present?
  end

  test "chart data includes biology report IDs for navigation" do
    create_test_results(2)
    
    get biomarker_trends_path(@biomarker)
    
    chart_data = assigns(:chart_data)
    assert chart_data[:datasets].first[:reportIds].present?
    assert_equal 2, chart_data[:datasets].first[:reportIds].size
  end

  private

  def create_test_results(count)
    reports = [@biology_report1, @biology_report2]
    
    count.times do |i|
      TestResult.create!(
        biology_report: reports[i],
        biomarker: @biomarker,
        value: 90 + (i * 10),
        unit: "mg/dL",
        ref_min: 70,
        ref_max: 100
      )
    end
  end
end
