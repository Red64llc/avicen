require "application_system_test_case"

class BiologyReportsFilteringTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as_system(@user)
  end

  test "filtering biology reports by date range without page reload" do
    visit biology_reports_path

    # Verify all reports are shown initially
    assert_text "LabCorp"
    assert_text "Quest Diagnostics"
    assert_text "December 20, 2024"

    # Apply date filter
    fill_in "From Date", with: "2025-01-01"
    fill_in "To Date", with: ""
    click_button "Filter"

    # Wait for Turbo Frame update
    assert_text "LabCorp"
    assert_text "Quest Diagnostics"
    # December 2024 report should be hidden
    assert_no_text "December 20, 2024"

    # Verify URL contains filter parameters
    assert_current_path biology_reports_path(date_from: "2025-01-01")
  end

  test "filtering biology reports by laboratory name without page reload" do
    visit biology_reports_path

    # Apply lab name filter
    fill_in "Laboratory", with: "Quest"
    click_button "Filter"

    # Wait for Turbo Frame update
    assert_text "Quest Diagnostics"
    # LabCorp reports should be hidden
    assert_no_text "LabCorp", wait: 1
  end

  test "filtering biology reports by date range and laboratory name" do
    visit biology_reports_path

    # Apply combined filters
    fill_in "From Date", with: "2025-01-01"
    fill_in "To Date", with: "2025-01-31"
    fill_in "Laboratory", with: "Quest"
    click_button "Filter"

    # Only Quest report from January should be shown
    assert_text "Quest Diagnostics"
    assert_text "January 15, 2025"
    assert_no_text "LabCorp"
    assert_no_text "December 20, 2024"
  end

  test "clearing filters shows all reports" do
    visit biology_reports_path(date_from: "2025-01-01", lab_name: "Quest")

    # Verify filtered state
    assert_text "Quest Diagnostics"
    assert_no_text "December 20, 2024"

    # Clear filters
    click_link "Clear"

    # All reports should be visible again
    assert_text "LabCorp"
    assert_text "Quest Diagnostics"
    assert_text "December 20, 2024"
  end

  test "filter form preserves values after filtering" do
    visit biology_reports_path

    # Apply filters
    fill_in "From Date", with: "2025-01-01"
    fill_in "Laboratory", with: "Quest"
    click_button "Filter"

    # Verify form values are preserved
    assert_field "From Date", with: "2025-01-01"
    assert_field "Laboratory", with: "Quest"
  end

  test "empty filter results show helpful message" do
    visit biology_reports_path

    # Apply filter that matches no results
    fill_in "Laboratory", with: "NonexistentLab"
    click_button "Filter"

    # Should show empty state message
    assert_text "No biology reports found"
  end
end
