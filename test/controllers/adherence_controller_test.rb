require "test_helper"

class AdherenceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "index requires authentication" do
    sign_out
    get adherence_path
    assert_redirected_to new_session_path
  end

  # --- Default behavior ---

  test "index renders the adherence history view" do
    get adherence_path
    assert_response :success
    assert_select "h1", /adherence/i
  end

  test "index defaults to 30 day period" do
    get adherence_path
    assert_response :success
    assert_match "30", response.body
  end

  # --- Period selection ---

  test "index accepts period parameter of 7" do
    get adherence_path, params: { period: "7" }
    assert_response :success
    assert_match "7", response.body
  end

  test "index accepts period parameter of 30" do
    get adherence_path, params: { period: "30" }
    assert_response :success
  end

  test "index accepts period parameter of 90" do
    get adherence_path, params: { period: "90" }
    assert_response :success
    assert_match "90", response.body
  end

  test "index defaults to 30 for invalid period parameter" do
    get adherence_path, params: { period: "15" }
    assert_response :success
    # Should fall back to 30
    assert_match "30", response.body
  end

  # --- Period selection controls ---

  test "index includes period selection buttons for 7, 30, and 90 days" do
    get adherence_path
    assert_response :success
    assert_select "a[href=?]", adherence_path(period: 7)
    assert_select "a[href=?]", adherence_path(period: 30)
    assert_select "a[href=?]", adherence_path(period: 90)
  end

  # --- Per-medication statistics table ---

  test "index displays per-medication statistics table" do
    get adherence_path
    assert_response :success
    assert_select "table"
  end

  test "index displays medication stats with scheduled, taken, skipped, missed, percentage" do
    get adherence_path
    assert_response :success
    # Headers should contain these terms
    assert_match(/scheduled/i, response.body)
    assert_match(/taken/i, response.body)
    assert_match(/skipped/i, response.body)
    assert_match(/missed/i, response.body)
  end

  # --- Calendar heatmap ---

  test "index displays calendar heatmap" do
    get adherence_path
    assert_response :success
    # Heatmap container should exist
    assert_select "[data-heatmap]"
  end

  test "heatmap day cells have aria-label attributes for accessibility" do
    get adherence_path
    assert_response :success
    # Each day cell should have an aria-label
    assert_select "[data-heatmap] [aria-label]"
  end

  test "heatmap day cells have --intensity CSS custom property" do
    get adherence_path
    assert_response :success
    # Day cells should set the --intensity variable
    assert_match "--intensity", response.body
  end

  # --- Date detail view ---

  test "index with date parameter displays detailed log entries" do
    # 2026-02-10 has logs in fixtures
    get adherence_path, params: { date: "2026-02-10" }
    assert_response :success
    # Should display detail for that day
    assert_match "February 10", response.body
  end

  test "index with date parameter shows log status for the day" do
    get adherence_path, params: { date: "2026-02-10" }
    assert_response :success
    # Should show taken and skipped statuses from fixture logs
    assert_match(/taken/i, response.body)
    assert_match(/skipped/i, response.body)
  end

  # --- Day click navigation ---

  test "heatmap day cells are clickable links to date detail" do
    get adherence_path
    assert_response :success
    # Day cells should link to adherence with date parameter
    assert_select "[data-heatmap] a[href*='date=']"
  end

  # --- Overall percentage ---

  test "index displays overall adherence percentage" do
    get adherence_path
    assert_response :success
    assert_match(/%/, response.body)
  end

  # --- Empty state ---

  test "index handles user with no medications gracefully" do
    sign_out
    sign_in_as(@other_user)

    get adherence_path
    assert_response :success
    # Should still render without errors
    assert_select "h1", /adherence/i
  end
end
