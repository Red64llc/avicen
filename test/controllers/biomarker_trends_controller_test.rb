require "test_helper"

class BiomarkerTrendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)

    @biomarker = biomarkers(:glucose)
    @biology_report1 = biology_reports(:one)
    @biology_report2 = biology_reports(:two)

    # Use an isolated biomarker for chart tests to avoid fixture interference
    @isolated_biomarker = biomarkers(:hdl)
    TestResult.where(biomarker: @isolated_biomarker).destroy_all
  end

  test "show returns 200 when biomarker has sufficient data" do
    create_test_results(2)

    get biomarker_trends_path(@isolated_biomarker)

    assert_response :success
    # Verify chart data is rendered in the response
    assert_match @isolated_biomarker.name, response.body
  end

  test "show renders table view when fewer than 2 data points" do
    # Use a biomarker without existing fixture data
    isolated_biomarker = biomarkers(:tsh)
    # Ensure no existing test results
    TestResult.where(biomarker: isolated_biomarker).destroy_all

    # Create exactly 1 test result
    TestResult.create!(
      biology_report: @biology_report1,
      biomarker: isolated_biomarker,
      value: 2.5,
      unit: "mIU/L",
      ref_min: 0.4,
      ref_max: 4.0
    )

    get biomarker_trends_path(isolated_biomarker)

    assert_response :success
    # Verify insufficient data message is shown (case-insensitive match)
    assert_match /Insufficient data/i, response.body
  end

  test "show returns 404 when biomarker not found" do
    get biomarker_trends_path(id: 99999)
    assert_response :not_found
  end

  test "show returns 404 when no data exists for user" do
    # Use a biomarker that has no test results for this user
    empty_biomarker = biomarkers(:tsh)
    # Ensure no test results exist for this biomarker
    TestResult.where(biomarker: empty_biomarker).destroy_all

    get biomarker_trends_path(empty_biomarker)

    assert_response :not_found
  end

  test "show scopes test results to current user" do
    # Use a biomarker without existing fixture data
    isolated_biomarker = biomarkers(:ldl)
    # Ensure no existing test results
    TestResult.where(biomarker: isolated_biomarker).destroy_all

    other_user = users(:two)
    other_report = BiologyReport.create!(
      user: other_user,
      test_date: Date.today,
      lab_name: "Other Lab"
    )

    # Create test result for current user
    TestResult.create!(
      biology_report: @biology_report1,
      biomarker: isolated_biomarker,
      value: 95,
      unit: "mg/dL",
      ref_min: 0,
      ref_max: 100
    )

    # Create test result for other user
    TestResult.create!(
      biology_report: other_report,
      biomarker: isolated_biomarker,
      value: 110,
      unit: "mg/dL",
      ref_min: 0,
      ref_max: 100
    )

    get biomarker_trends_path(isolated_biomarker)

    # Should only have 1 data point (current user's), so shows insufficient data view
    assert_response :success
    assert_match /Insufficient data/i, response.body
  end

  test "chart data includes test dates as labels" do
    create_test_results(2)

    get biomarker_trends_path(@isolated_biomarker)

    assert_response :success
    # Chart data is embedded in the page for Chart.js
    assert_match @biology_report1.test_date.to_s, response.body
    assert_match @biology_report2.test_date.to_s, response.body
  end

  test "chart data includes values in datasets" do
    create_test_results(2)

    get biomarker_trends_path(@isolated_biomarker)

    assert_response :success
    # Values are embedded in chart data
    assert_match "90", response.body
    assert_match "100", response.body
  end

  test "chart data includes reference range annotations" do
    create_test_results(2)

    get biomarker_trends_path(@isolated_biomarker)

    assert_response :success
    # Reference range info should be in the page
    assert_match "40", response.body  # HDL ref_min
    assert_match "999", response.body # HDL ref_max
  end

  test "chart data includes biology report IDs for navigation" do
    create_test_results(2)

    get biomarker_trends_path(@isolated_biomarker)

    assert_response :success
    # Report IDs should be embedded in chart data for click navigation
    assert_match @biology_report1.id.to_s, response.body
    assert_match @biology_report2.id.to_s, response.body
  end

  private

  def create_test_results(count)
    reports = [ @biology_report1, @biology_report2 ]

    count.times do |i|
      TestResult.create!(
        biology_report: reports[i],
        biomarker: @isolated_biomarker,
        value: 90 + (i * 10),
        unit: "mg/dL",
        ref_min: 40,
        ref_max: 999
      )
    end
  end
end
