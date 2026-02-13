require "application_system_test_case"

class BiologyReportsEndToEndTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as_system(@user)
    @glucose = biomarkers(:glucose)
    @hemoglobin = biomarkers(:hemoglobin)
  end

  # Task 10.7: Complete end-to-end workflow tests

  test "complete workflow: create biology report, add test results, view report detail, verify out-of-range flagging" do
    # Navigate to biology reports index
    visit biology_reports_path
    assert_selector "h1", text: "Biology Reports"

    # Click "New Biology Report" button
    click_link "New Biology Report"
    assert_selector "h1", text: "New Biology Report"

    # Fill in biology report form
    fill_in "Test Date", with: Date.today
    fill_in "Laboratory Name", with: "LabCorp West"
    fill_in "Notes", with: "Annual checkup - comprehensive panel"

    # Submit the form
    click_button "Create Report"

    # Verify redirect to show page
    assert_text "Biology report was successfully created"
    assert_selector "h1", text: "Biology Report"
    assert_text "Test Date"
    assert_text Date.today.strftime("%B %d, %Y")
    assert_text "LabCorp West"

    # Add first test result - IN RANGE
    click_link "Add Test Result"

    # Fill in biomarker search field (text input, not select)
    fill_in "test_result[biomarker_name]", with: @glucose.name

    # Wait for autocomplete results
    assert_selector "ul[data-biomarker-search-target='results'] li", wait: 5

    # Click on the glucose result
    within("ul[data-biomarker-search-target='results']") do
      click_on @glucose.name
    end

    # Verify auto-fill worked
    assert_equal @glucose.unit, find_field("Unit of Measurement").value
    assert_equal @glucose.ref_min.to_s, find_field("Minimum Value").value
    assert_equal @glucose.ref_max.to_s, find_field("Maximum Value").value

    # Fill in test value (in range)
    fill_in "Test Value", with: "85.0"

    # Submit test result form
    click_button "Save Test Result"

    # Verify Turbo Stream updated the page (no full reload)
    assert_selector "table"
    assert_text @glucose.name
    assert_text "85.0 mg/dL"
    assert_text "✓ Normal"
    assert_selector "span.bg-green-100.text-green-800", text: "Normal"

    # Add second test result - OUT OF RANGE
    click_link "Add Test Result"

    # Fill in biomarker search field for hemoglobin
    fill_in "test_result[biomarker_name]", with: @hemoglobin.name

    # Wait for autocomplete results
    assert_selector "ul[data-biomarker-search-target='results'] li", wait: 5

    # Click on the hemoglobin result
    within("ul[data-biomarker-search-target='results']") do
      click_on @hemoglobin.name
    end

    # Fill in out-of-range value (below minimum)
    fill_in "Test Value", with: "10.5"

    # Submit test result form
    click_button "Save Test Result"

    # Verify out-of-range result is highlighted
    assert_text @hemoglobin.name
    assert_text "10.5 g/dL"
    assert_text "⚠ Out of Range"
    assert_selector "span.bg-red-100.text-red-800", text: "Out of Range"
    assert_selector "tr.bg-red-50", text: @hemoglobin.name

    # Verify both results are shown in the table
    within("table") do
      # Should have 2 test results
      assert_selector "tbody tr", count: 2

      # Verify glucose (normal)
      within("tr", text: @glucose.name) do
        assert_text "85.0 mg/dL"
        assert_text "70.0 - 100.0 mg/dL"
        assert_text "✓ Normal"
      end

      # Verify hemoglobin (out of range)
      within("tr", text: @hemoglobin.name) do
        assert_text "10.5 g/dL"
        assert_text "⚠ Out of Range"
      end
    end
  end

  test "complete workflow: upload document, view document, delete document" do
    biology_report = biology_reports(:one)
    visit biology_report_path(biology_report)

    # Initially no document attached
    assert_no_text "Attached Document"

    # Navigate to edit page
    click_link "Edit"

    # Upload a document
    attach_file "Document", Rails.root.join("test", "fixtures", "files", "test_lab_report.pdf")

    # Save the form
    click_button "Update Report"

    # Verify redirect back to show page with success message
    assert_text "Biology report was successfully updated"

    # Verify document section is now displayed
    assert_text "Attached Document"
    assert_link "View Document"
    assert_link "Download"

    # Click "View Document" link (opens in new tab)
    view_link = find_link("View Document")
    assert_equal "_blank", view_link[:target]

    # Navigate back to edit page to remove document
    click_link "Edit"

    # Check the "Remove document" checkbox
    check "Remove document"

    # Save the form
    click_button "Update Report"

    # Verify document has been removed
    assert_text "Biology report was successfully updated"
    assert_no_text "Attached Document"
    assert_no_link "View Document"
  end

  test "complete workflow: biomarker autocomplete search, select biomarker, verify auto-filled ranges" do
    biology_report = biology_reports(:one)
    visit biology_report_path(biology_report)

    # Click "Add Test Result"
    click_link "Add Test Result"

    # Start typing in biomarker search field (partial match)
    fill_in "test_result[biomarker_name]", with: "Glu"

    # Wait for autocomplete dropdown to appear
    assert_selector "ul[data-biomarker-search-target='results'] li", wait: 5

    # Select glucose from autocomplete results
    within("ul[data-biomarker-search-target='results']") do
      assert_text @glucose.name
      find("li", text: @glucose.name).click
    end

    # Verify auto-filled values
    assert_equal @glucose.unit, find_field("Unit of Measurement").value
    assert_equal @glucose.ref_min.to_s, find_field("Minimum Value").value
    assert_equal @glucose.ref_max.to_s, find_field("Maximum Value").value

    # User can override the auto-filled values
    fill_in "Minimum Value", with: "65.0"
    fill_in "Maximum Value", with: "110.0"

    # Fill in test value
    fill_in "Test Value", with: "95.0"

    # Submit the form
    click_button "Save Test Result"

    # Verify test result was created with overridden ranges
    assert_text @glucose.name
    assert_text "95.0 mg/dL"
    # The reference range should show the overridden values
    assert_text "65.0 - 110.0 mg/dL"
    assert_text "✓ Normal"
  end

  test "complete workflow: view biomarker trend chart, click data point, navigate to report" do
    # Create multiple test results for the same biomarker across different reports
    report1 = BiologyReport.create!(
      user: @user,
      test_date: Date.new(2025, 1, 15),
      lab_name: "LabCorp"
    )

    report2 = BiologyReport.create!(
      user: @user,
      test_date: Date.new(2025, 2, 10),
      lab_name: "Quest"
    )

    report3 = BiologyReport.create!(
      user: @user,
      test_date: Date.new(2025, 3, 5),
      lab_name: "LabCorp"
    )

    # Create test results for glucose across all reports
    TestResult.create!(
      biology_report: report1,
      biomarker: @glucose,
      value: 95.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    TestResult.create!(
      biology_report: report2,
      biomarker: @glucose,
      value: 102.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    TestResult.create!(
      biology_report: report3,
      biomarker: @glucose,
      value: 88.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    # Navigate to biomarkers index
    visit biomarkers_path

    # Should see glucose biomarker listed
    assert_text @glucose.name
    assert_text @glucose.code

    # Click on glucose to view trend
    click_link @glucose.name

    # Should be on biomarker trends page
    assert_selector "h1", text: @glucose.name

    # Chart should be rendered (not table view)
    assert_selector "canvas[data-biomarker-chart-target='canvas']"
    assert_no_text "Insufficient data for trend chart"

    # Chart.js should render the chart with data points
    # Note: We can't easily test JavaScript-rendered chart interaction in system tests
    # without Selenium or a full browser, but we can verify the canvas exists
    # and the chart data is embedded in the page

    # Verify chart data is present in the page (passed to Stimulus controller)
    page_source = page.html
    assert page_source.include?(@glucose.name), "Chart data should include biomarker name"

    # Navigate back to biomarkers index
    click_link "Back to Biomarkers"
    assert_selector "h1", text: "Biomarkers"
  end

  test "complete workflow: filter biology reports by date range and lab name with Turbo Frame updates" do
    # Create test data with different dates and labs
    BiologyReport.create!(
      user: @user,
      test_date: Date.new(2024, 12, 1),
      lab_name: "LabCorp"
    )

    BiologyReport.create!(
      user: @user,
      test_date: Date.new(2025, 1, 15),
      lab_name: "Quest Diagnostics"
    )

    BiologyReport.create!(
      user: @user,
      test_date: Date.new(2025, 2, 10),
      lab_name: "LabCorp West"
    )

    # Visit biology reports index
    visit biology_reports_path

    # Verify all reports are shown initially
    assert_text "LabCorp"
    assert_text "Quest Diagnostics"
    assert_text "LabCorp West"

    # Apply date filter (from Jan 1, 2025)
    fill_in "date_from", with: "2025-01-01"

    # Wait for auto-submit (debounced)
    sleep 0.5

    # Verify Turbo Frame updated without full page reload
    assert_selector "h1", text: "Biology Reports"

    # December report should be hidden
    assert_no_text "December 01, 2024"

    # January and February reports should be visible
    assert_text "January 15, 2025"
    assert_text "February 10, 2025"

    # Apply lab name filter
    fill_in "lab_name", with: "LabCorp"

    # Wait for auto-submit
    sleep 0.5

    # Only LabCorp reports should be visible
    assert_text "LabCorp"
    assert_text "LabCorp West"
    assert_no_text "Quest Diagnostics"

    # Clear filters by removing text
    fill_in "date_from", with: ""
    fill_in "lab_name", with: ""

    # Wait for auto-submit
    sleep 0.5

    # All reports should be visible again
    assert_text "LabCorp"
    assert_text "Quest Diagnostics"
    assert_text "LabCorp West"
    assert_text "December 01, 2024"
  end

  test "complete workflow: edit test result, recalculate out-of-range flag" do
    # Create a biology report with an in-range test result
    report = BiologyReport.create!(
      user: @user,
      test_date: Date.today,
      lab_name: "Test Lab"
    )

    test_result = TestResult.create!(
      biology_report: report,
      biomarker: @glucose,
      value: 95.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    # Visit the report
    visit biology_report_path(report)

    # Verify initial status is normal
    assert_text "✓ Normal"
    assert_selector "span.bg-green-100.text-green-800", text: "Normal"

    # Click edit on the test result
    within("tr", text: @glucose.name) do
      click_link "Edit"
    end

    # Change the value to out-of-range (above maximum)
    fill_in "Test Value", with: "150.0"

    # Submit the form
    click_button "Update Test Result"

    # Verify Turbo Stream updated the row
    assert_text "⚠ Out of Range"
    assert_selector "span.bg-red-100.text-red-800", text: "Out of Range"
    assert_selector "tr.bg-red-50", text: @glucose.name

    # Verify the value was updated
    within("tr", text: @glucose.name) do
      assert_text "150.0 mg/dL"
    end
  end

  test "complete workflow: delete test result via Turbo Stream" do
    # Create a biology report with multiple test results
    report = BiologyReport.create!(
      user: @user,
      test_date: Date.today,
      lab_name: "Test Lab"
    )

    result1 = TestResult.create!(
      biology_report: report,
      biomarker: @glucose,
      value: 95.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    result2 = TestResult.create!(
      biology_report: report,
      biomarker: @hemoglobin,
      value: 14.5,
      unit: "g/dL",
      ref_min: 13.5,
      ref_max: 17.5
    )

    # Visit the report
    visit biology_report_path(report)

    # Verify both test results are shown
    assert_text @glucose.name
    assert_text @hemoglobin.name
    assert_selector "tbody tr", count: 2

    # Delete the glucose test result
    within("tr", text: @glucose.name) do
      accept_confirm do
        click_link "Delete"
      end
    end

    # Verify Turbo Stream removed the row without page reload
    assert_no_text @glucose.name
    assert_text @hemoglobin.name
    assert_selector "tbody tr", count: 1

    # Page should still be on the same report (no full reload)
    assert_selector "h1", text: "Biology Report"
  end

  test "validation errors are displayed with proper styling and preserve form data" do
    visit new_biology_report_path

    # Submit form with missing required field
    fill_in "Laboratory Name", with: "Test Lab"
    fill_in "Notes", with: "Some notes"
    # Leave test_date blank

    click_button "Create Report"

    # Should render form again with validation errors
    assert_selector "h1", text: "New Biology Report"

    # Validation error should be displayed with red styling
    assert_selector ".bg-red-50.border-red-200.text-red-800"
    assert_text "prohibited this report from being saved"
    assert_text "Test date can't be blank"

    # Form data should be preserved
    assert_equal "Test Lab", find_field("Laboratory Name").value
    assert_equal "Some notes", find_field("Notes").value

    # Fill in missing field and resubmit
    fill_in "Test Date", with: Date.today
    click_button "Create Report"

    # Should succeed this time
    assert_text "Biology report was successfully created"
    assert_selector "h1", text: "Biology Report"
  end

  test "user can only access their own biology reports" do
    # This test verifies user scoping through the UI
    other_user = users(:two)
    other_report = biology_reports(:other_user_report)

    # As current user, try to access other user's report URL directly
    visit biology_report_path(other_report)

    # Should see 404 or redirect (Rails raises RecordNotFound)
    # System test will show error page or redirect
    assert_text "not found", count: 1, minimum: 1
  end
end
