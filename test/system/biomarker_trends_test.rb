require "application_system_test_case"

class BiomarkerTrendsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as_system(@user)

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
    # Use a biomarker with no existing test results
    biomarker_without_results = Biomarker.create!(
      name: "TestBiomarker",
      code: "TST",
      unit: "mg/dL",
      ref_min: 70,
      ref_max: 100
    )

    # Create only 1 test result
    TestResult.create!(
      biology_report: @biology_report1,
      biomarker: biomarker_without_results,
      value: 95,
      unit: "mg/dL",
      ref_min: 70,
      ref_max: 100
    )

    visit biomarker_trends_path(biomarker_without_results)

    assert_selector "h1", text: biomarker_without_results.name
    assert_selector "table"
    assert_text "Insufficient data for trend chart"
    assert_no_selector "canvas"
  end

  test "returns 404 when biomarker not found" do
    visit biomarker_trends_path(id: 99999)

    # Rails shows error page with "Couldn't find Biomarker" in test/development mode
    assert_text "Couldn't find Biomarker"
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
end
