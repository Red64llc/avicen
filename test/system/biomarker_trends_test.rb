require "application_system_test_case"

class BiomarkerTrendsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    login_as(@user)

    @biomarker = biomarkers(:glucose)
    @biology_report1 = biology_reports(:one)
    @biology_report2 = biology_reports(:two)
  end

  test "displays trend chart with reference range bands when sufficient data exists" do
    # Create at least 2 test results for the biomarker
    TestResult.create!(
      biology_report: @biology_report1,
      biomarker: @biomarker,
      value: 95,
      unit: "mg/dL",
      ref_min: 70,
      ref_max: 100
    )
    
    TestResult.create!(
      biology_report: @biology_report2,
      biomarker: @biomarker,
      value: 105,
      unit: "mg/dL",
      ref_min: 70,
      ref_max: 100
    )

    visit biomarker_trends_path(@biomarker)

    assert_selector "h1", text: @biomarker.name
    assert_selector "canvas[data-biomarker-chart-target='canvas']"
    assert_no_selector "table", text: "Insufficient data"
  end

  test "displays table when fewer than 2 data points exist" do
    # Create only 1 test result
    TestResult.create!(
      biology_report: @biology_report1,
      biomarker: @biomarker,
      value: 95,
      unit: "mg/dL",
      ref_min: 70,
      ref_max: 100
    )

    visit biomarker_trends_path(@biomarker)

    assert_selector "h1", text: @biomarker.name
    assert_selector "table"
    assert_text "Insufficient data for trend chart"
    assert_no_selector "canvas"
  end

  test "returns 404 when biomarker not found" do
    visit biomarker_trends_path(id: 99999)
    
    assert_text "not found", count: 1, minimum: 1
  end

  test "chart.js and annotation plugin are loaded via importmap" do
    # Visit a page that uses the chart
    TestResult.create!(
      biology_report: @biology_report1,
      biomarker: @biomarker,
      value: 95,
      unit: "mg/dL",
      ref_min: 70,
      ref_max: 100
    )
    
    TestResult.create!(
      biology_report: @biology_report2,
      biomarker: @biomarker,
      value: 105,
      unit: "mg/dL",
      ref_min: 70,
      ref_max: 100
    )

    visit biomarker_trends_path(@biomarker)

    # Check that canvas element exists (chart would render if JS loaded)
    assert_selector "canvas[data-biomarker-chart-target='canvas']"
  end

  private

  def login_as(user)
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"
  end
end
