require "test_helper"

class BiologyReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    sign_in_as(@user)
    @biology_report = biology_reports(:one)
  end

  # Index action tests
  test "should get index" do
    get biology_reports_url
    assert_response :success
    assert_select "h1", "Biology Reports"
  end

  test "index should scope reports to current user" do
    get biology_reports_url
    assert_response :success
    # Verify current user's reports are shown
    assert_match "February 01, 2025", response.body
    assert_match "January 15, 2025", response.body
  end

  test "index should order reports by test_date descending" do
    get biology_reports_url
    assert_response :success
    # Most recent date should appear first
    assert_match /Feb.*Jan.*Dec/m, response.body
  end

  # Filtering tests
  test "index should filter by date_from" do
    get biology_reports_url, params: { date_from: "2025-01-01" }
    assert_response :success
    # Should show reports from Jan and Feb, not Dec
    assert_match "February 01, 2025", response.body
    assert_match "January 15, 2025", response.body
    assert_no_match "December 20, 2024", response.body
  end

  test "index should filter by date_to" do
    get biology_reports_url, params: { date_to: "2025-01-31" }
    assert_response :success
    # Should show reports from Jan and Dec, not Feb
    assert_match "January 15, 2025", response.body
    assert_match "December 20, 2024", response.body
    assert_no_match "February 01, 2025", response.body
  end

  test "index should filter by lab_name" do
    get biology_reports_url, params: { lab_name: "LabCorp" }
    assert_response :success
    # Should only show LabCorp reports
    assert_match "LabCorp", response.body
    assert_no_match "Quest", response.body
  end

  test "index should filter by date range and lab_name" do
    get biology_reports_url, params: { date_from: "2025-01-01", date_to: "2025-12-31", lab_name: "Quest" }
    assert_response :success
    # Should only show Quest report from Jan-Dec range
    assert_match "Quest", response.body
    assert_no_match "December 20, 2024", response.body # LabCorp in Dec
  end

  test "index should return turbo_frame for turbo_frame requests" do
    get biology_reports_url, headers: { "Turbo-Frame" => "biology_reports_list" }
    assert_response :success
    # Should render partial without full page layout
    assert_no_match /<h1.*Biology Reports/, response.body
    # Should have the report list content
    assert_match /LabCorp/, response.body
  end

  # Show action tests
  test "should show biology_report" do
    get biology_report_url(@biology_report)
    assert_response :success
    assert_select "h1", "Biology Report"
  end

  test "should not show other user's biology_report" do
    other_report = biology_reports(:other_user_report)
    assert_raises(ActiveRecord::RecordNotFound) do
      get biology_report_url(other_report)
    end
  end

  # New action tests
  test "should get new" do
    get new_biology_report_url
    assert_response :success
    assert_select "h1", "New Biology Report"
  end

  # Create action tests
  test "should create biology_report with valid params" do
    assert_difference("BiologyReport.count") do
      post biology_reports_url, params: {
        biology_report: {
          test_date: "2025-02-10",
          lab_name: "Quest Diagnostics",
          notes: "Routine check-up"
        }
      }
    end

    assert_redirected_to biology_report_url(BiologyReport.last)
    assert_equal "Biology report was successfully created.", flash[:notice]
  end

  test "should not create biology_report with invalid params" do
    assert_no_difference("BiologyReport.count") do
      post biology_reports_url, params: {
        biology_report: {
          test_date: nil,
          lab_name: "Quest"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "created biology_report should belong to current user" do
    post biology_reports_url, params: {
      biology_report: {
        test_date: "2025-02-10",
        lab_name: "LabCorp"
      }
    }

    created_report = BiologyReport.last
    assert_equal @user.id, created_report.user_id
  end

  # Edit action tests
  test "should get edit" do
    get edit_biology_report_url(@biology_report)
    assert_response :success
    assert_select "h1", "Edit Biology Report"
  end

  test "should not get edit for other user's biology_report" do
    other_report = biology_reports(:other_user_report)
    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_biology_report_url(other_report)
    end
  end

  # Update action tests
  test "should update biology_report with valid params" do
    patch biology_report_url(@biology_report), params: {
      biology_report: {
        test_date: "2025-03-15",
        lab_name: "Updated Lab",
        notes: "Updated notes"
      }
    }

    assert_redirected_to biology_report_url(@biology_report)
    @biology_report.reload
    assert_equal Date.parse("2025-03-15"), @biology_report.test_date
    assert_equal "Updated Lab", @biology_report.lab_name
    assert_equal "Updated notes", @biology_report.notes
  end

  test "should not update biology_report with invalid params" do
    patch biology_report_url(@biology_report), params: {
      biology_report: {
        test_date: nil
      }
    }

    assert_response :unprocessable_entity
  end

  test "should not update other user's biology_report" do
    other_report = biology_reports(:other_user_report)
    assert_raises(ActiveRecord::RecordNotFound) do
      patch biology_report_url(other_report), params: {
        biology_report: {
          lab_name: "Hacked Lab"
        }
      }
    end
  end

  # Destroy action tests
  test "should destroy biology_report" do
    assert_difference("BiologyReport.count", -1) do
      delete biology_report_url(@biology_report)
    end

    assert_redirected_to biology_reports_url
  end

  test "should cascade delete test_results when destroying biology_report" do
    # Create test results for the report (using fixtures)
    biomarker = Biomarker.first
    skip "Biomarker fixtures not loaded" unless biomarker

    @biology_report.test_results.create!(
      biomarker: biomarker,
      value: 95.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    assert_difference(["BiologyReport.count", "TestResult.count"], -1) do
      delete biology_report_url(@biology_report)
    end
  end

  test "should not destroy other user's biology_report" do
    other_report = biology_reports(:other_user_report)
    assert_raises(ActiveRecord::RecordNotFound) do
      delete biology_report_url(other_report)
    end
  end

  test "unauthenticated users should be redirected to login" do
    sign_out
    get biology_reports_url
    assert_redirected_to new_session_url
  end
end
