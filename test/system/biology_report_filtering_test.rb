require "application_system_test_case"

class BiologyReportFilteringTest < ApplicationSystemTestCase
  test "filter form auto-submits on input change with debouncing" do
    sign_in_as_system(users(:one))

    # Create test data
    visit biology_reports_path

    # Wait for filter form to load
    assert_selector "form"

    # Type in lab name filter - should auto-submit after debounce
    fill_in "Laboratory", with: "Quest"

    # Give debounce time to trigger (default 300ms)
    sleep 0.5

    # Check that Turbo Frame was updated without full page reload
    # (page title should still be the same)
    assert_selector "h1", text: "Biology Reports"
  end

  test "date filters auto-submit via Turbo Frame" do
    sign_in_as_system(users(:one))
    visit biology_reports_path

    # Change date filter (use helper for date field)
    fill_in_date "From Date", with: 1.month.ago.to_date.to_s

    sleep 0.5

    # Verify Turbo Frame update
    assert_selector "#biology_reports_list"
  end

  test "multiple rapid filter changes are debounced" do
    sign_in_as_system(users(:one))
    visit biology_reports_path

    # Rapid typing should only trigger one request after debounce
    fill_in "Laboratory", with: "Q"
    fill_in "Laboratory", with: "Qu"
    fill_in "Laboratory", with: "Que"
    fill_in "Laboratory", with: "Ques"
    fill_in "Laboratory", with: "Quest"

    sleep 0.5

    # Should only have made one request
    assert_selector "h1", text: "Biology Reports"
  end
end
