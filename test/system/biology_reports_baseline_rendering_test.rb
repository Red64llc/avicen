require "application_system_test_case"

class BiologyReportsBaselineRenderingTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as_system(@user)
  end

  # Task 10.8: Baseline rendering tests for UI components

  test "biology report index page renders correctly" do
    visit biology_reports_path

    # Verify page heading
    assert_selector "h1", text: "Biology Reports"

    # Verify main container exists
    assert_selector "div.container, div.mx-auto"

    # Verify "New Report" button exists (links to document scanning workflow)
    assert_link "New Report", href: new_document_scan_path

    # Verify Turbo Frame for reports list exists
    assert_selector "turbo-frame#biology_reports_list"
  end

  test "biology report show page renders with test results" do
    biology_report = biology_reports(:one)

    # Create a test result
    test_result = biology_report.test_results.create!(
      biomarker: biomarkers(:glucose),
      value: 95.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    visit biology_report_path(biology_report)

    # Verify page heading
    assert_selector "h1", text: "Biology Report"

    # Verify report metadata section exists
    assert_text "Test Date"
    assert_text biology_report.test_date.strftime("%B %d, %Y")

    # Verify test results section heading
    assert_text "Test Results"

    # Verify test results table renders
    assert_selector "table"
    assert_selector "table thead"
    assert_selector "table tbody"

    # Verify table headers (use case-insensitive match since CSS may transform text)
    within "table thead" do
      assert_selector "th", text: /biomarker/i
      assert_selector "th", text: /value/i
      assert_selector "th", text: /reference range/i
      assert_selector "th", text: /status/i
    end

    # Verify test result row renders
    within "table tbody" do
      assert_selector "tr", minimum: 1
      assert_text biomarkers(:glucose).name
      assert_text "95.0 mg/dL"
    end
  end

  test "biomarker trend chart canvas element present" do
    # Create multiple test results for trend visualization
    glucose = biomarkers(:glucose)

    report1 = BiologyReport.create!(
      user: @user,
      test_date: Date.new(2025, 1, 15),
      lab_name: "Lab 1"
    )

    report2 = BiologyReport.create!(
      user: @user,
      test_date: Date.new(2025, 2, 15),
      lab_name: "Lab 2"
    )

    TestResult.create!(
      biology_report: report1,
      biomarker: glucose,
      value: 95.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    TestResult.create!(
      biology_report: report2,
      biomarker: glucose,
      value: 88.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    visit biomarker_trends_path(glucose)

    # Verify page heading with biomarker name
    assert_selector "h1", text: glucose.name

    # Verify chart container with Stimulus controller
    assert_selector "[data-controller='biomarker-chart']"

    # Verify canvas element for Chart.js
    assert_selector "canvas[data-biomarker-chart-target='canvas']"

    # Verify chart data is passed to Stimulus controller
    chart_container = find("[data-controller='biomarker-chart']")
    assert chart_container["data-biomarker-chart-chart-data-value"].present?,
      "Chart data should be passed to Stimulus controller"
  end

  test "filter form renders with date and lab inputs" do
    visit biology_reports_path

    # Verify filter form exists
    assert_selector "form[action='#{biology_reports_path}']"

    # Verify form has Turbo Frame target
    form = find("form[action='#{biology_reports_path}']")
    assert_equal "biology_reports_list", form["data-turbo-frame"]

    # Verify date range inputs
    within "form[action='#{biology_reports_path}']" do
      # Date from input
      assert_selector "input#date_from, input[name='date_from']"
      date_from_input = find("input#date_from, input[name='date_from']")
      assert_equal "date", date_from_input[:type]

      # Date to input
      assert_selector "input#date_to, input[name='date_to']"
      date_to_input = find("input#date_to, input[name='date_to']")
      assert_equal "date", date_to_input[:type]

      # Lab name input
      assert_selector "input#lab_name, input[name='lab_name']"
      lab_name_input = find("input#lab_name, input[name='lab_name']")
      assert_equal "text", lab_name_input[:type]
    end

    # Verify filter form has Stimulus controller for auto-submit
    assert_selector "form[data-controller*='filter-form']"
  end

  test "biology report index handles empty state correctly" do
    # Delete all biology reports for the user
    @user.biology_reports.destroy_all

    visit biology_reports_path

    # Page should still render
    assert_selector "h1", text: "Biology Reports"

    # Should show empty state message or no reports
    within "turbo-frame#biology_reports_list" do
      # Either empty message or no report cards
      assert_no_selector ".bg-white.rounded-lg.shadow", text: /Laboratory|Test Date/
    end

    # New Report button should still be available
    assert_link "New Report"
  end

  test "biology report show page handles empty test results correctly" do
    biology_report = biology_reports(:one)
    biology_report.test_results.destroy_all

    visit biology_report_path(biology_report)

    # Page should still render
    assert_selector "h1", text: "Biology Report"

    # Test Results section should indicate no results
    assert_text "Test Results"

    # Should not render table when no results
    assert_no_selector "table"

    # Should show empty message
    assert_text "No test results yet"
  end

  test "biomarker trend page handles insufficient data correctly" do
    # Use TSH which has no existing test results in fixtures
    tsh = biomarkers(:tsh)

    report = BiologyReport.create!(
      user: @user,
      test_date: Date.today,
      lab_name: "Test Lab"
    )

    # Create only one test result (need 2+ for chart)
    TestResult.create!(
      biology_report: report,
      biomarker: tsh,
      value: 2.5,
      unit: "mIU/L",
      ref_min: 0.4,
      ref_max: 4.0
    )

    visit biomarker_trends_path(tsh)

    # Page should still render
    assert_selector "h1", text: tsh.name

    # Should show message about insufficient data
    assert_text "Insufficient data for trend chart"

    # Should show table view instead of chart
    assert_selector "table"
    assert_no_selector "canvas"
  end
end
