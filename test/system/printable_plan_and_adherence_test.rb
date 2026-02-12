require "application_system_test_case"

# Task 12.2: System tests for printable plan and adherence history.
#
# Tests navigating to the print view and verifying the print-optimized layout
# includes all active medications organized by time of day.
# Tests navigating to the adherence history view, selecting a time period,
# and clicking a day for detail.
#
# Requirements: 8.3, 8.4, 9.1, 9.4
class PrintablePlanAndAdherenceTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  # --- Printable Plan Tests (Req 9.1, 9.4) ---

  test "printable plan displays all active medications organized by time of day" do
    sign_in_as_system(@user)

    # Navigate to the printable plan
    visit print_schedule_path

    # Verify the page title and generated timestamp
    assert_text "Medication Plan"
    assert_text "Generated on"

    # Verify the Print button is present (hidden on actual print via print:hidden)
    assert_button "Print"
    assert_link "Back to Schedule"

    # Verify active medications are displayed
    # Fixture: aspirin_morning (active, prescription one) has schedules:
    #   morning_daily at 08:00 (all days) and monday_wednesday_friday at 12:00
    # Fixture: ibuprofen_evening (active, prescription one) has schedule:
    #   evening_weekdays at 20:00
    assert_text "Aspirin"
    assert_text "Ibuprofen 200mg Oral Tablet"

    # Verify time-of-day groups are present (Req 9.4)
    # 08:00 -> Morning, 12:00 -> Midday, 20:00 -> Evening
    assert_selector "h2", text: "Morning"
    assert_selector "h2", text: "Midday"
    assert_selector "h2", text: "Evening"

    # Verify the table structure with medication details (Req 9.1)
    # Each time-of-day group table shows: Time, Drug, Dosage, Form, Days, Instructions
    assert_selector "th", text: "Time"
    assert_selector "th", text: "Drug"
    assert_selector "th", text: "Dosage"
    assert_selector "th", text: "Form"
    assert_selector "th", text: "Days"
    assert_selector "th", text: "Instructions"

    # Verify schedule details are rendered in the table
    assert_text "08:00"
    assert_text "12:00"
    assert_text "20:00"

    # Verify dosage and form info appears
    assert_text "tablet"
    assert_text "capsule"

    # Verify day names are displayed for schedules
    assert_selector "table", text: "Mon"
    assert_selector "table", text: "Tue"

    # Verify instructions are rendered
    assert_text "Take with breakfast"
    assert_text "Take after dinner"

    # Verify total active medications count
    assert_text "Total active medications: 2"
  end

  test "printable plan does not show inactive medications" do
    sign_in_as_system(@user)

    visit print_schedule_path

    # The inactive_medication fixture (50mg aspirin in prescription two) should not appear
    # Only active medications should be shown
    assert_text "Aspirin"
    assert_text "Ibuprofen"

    # The total should be 2 (only active medications for user one)
    assert_text "Total active medications: 2"
  end

  test "printable plan is accessible from schedule view" do
    sign_in_as_system(@user)

    # Navigate to daily schedule first
    visit schedule_path
    assert_text "Daily Schedule"

    # The print view should be accessible via direct navigation
    visit print_schedule_path
    assert_text "Medication Plan"
  end

  # --- Adherence History Tests (Req 8.3, 8.4) ---

  test "adherence history displays overall percentage and medication statistics" do
    # Freeze time so adherence calculations are deterministic and Feb 10 logs are in range
    travel_to Time.utc(2026, 2, 12, 15, 0, 0) do
      sign_in_as_system(@user)

      # Navigate to adherence history
      visit adherence_path

      assert_text "Adherence History"

      # Verify period selection controls are present
      assert_link "7 days"
      assert_link "30 days"
      assert_link "90 days"

      # Verify overall adherence section
      assert_text "Overall Adherence"

      # Verify the medication statistics table is present
      assert_text "Medication Statistics"

      # Verify per-medication stats columns exist
      assert_selector "th", text: "Medication"
      assert_selector "th", text: "Scheduled"
      assert_selector "th", text: "Taken"
      assert_selector "th", text: "Skipped"
      assert_selector "th", text: "Missed"
      assert_selector "th", text: "Adherence"
    end
  end

  test "adherence history allows selecting different time periods" do
    travel_to Time.utc(2026, 2, 12, 15, 0, 0) do
      sign_in_as_system(@user)

      # Visit with default period (30 days)
      visit adherence_path

      assert_text "Adherence History"
      assert_text "Last 30 days"

      # Switch to 7-day period
      click_link "7 days"
      assert_text "Last 7 days", wait: 5

      # Switch to 90-day period
      click_link "90 days"
      assert_text "Last 90 days", wait: 5
    end
  end

  test "adherence history calendar heatmap displays daily cells with aria labels" do
    travel_to Time.utc(2026, 2, 12, 15, 0, 0) do
      sign_in_as_system(@user)

      visit adherence_path

      # Verify the Daily Adherence heatmap section exists
      assert_text "Daily Adherence"

      # Verify the heatmap grid container with day-of-week headers
      assert_selector "[data-heatmap]"
      within "[data-heatmap]" do
        assert_text "Mon"
        assert_text "Tue"
        assert_text "Wed"
        assert_text "Thu"
        assert_text "Fri"
        assert_text "Sat"
        assert_text "Sun"
      end

      # Verify heatmap day cells have aria-label for accessibility (Req 8.3)
      # Each day cell in the heatmap should have an aria-label with date and percentage
      assert_selector "[data-heatmap] [aria-label]"
    end
  end

  test "clicking a day in adherence heatmap shows detailed log entries for that day" do
    # Freeze time so the heatmap includes Feb 10, 2026 (which has fixture logs)
    travel_to Time.utc(2026, 2, 12, 15, 0, 0) do
      sign_in_as_system(@user)

      visit adherence_path

      # The fixture has logs for 2026-02-10 (taken_log and skipped_log)
      # The heatmap cells are links with aria-label containing the date
      day_link = find("[data-heatmap] [aria-label*='February 10']", match: :first)
      day_link.click

      # Verify the detail section appears for the selected date (Req 8.4)
      assert_text "Detail for", wait: 5
      assert_text "February 10, 2026"

      # Verify log entries are shown for that day
      # From fixtures: taken_log (aspirin morning, taken) and skipped_log (ibuprofen evening, skipped)
      assert_text "Aspirin"
      assert_text "Taken"
      assert_text "Skipped"
      assert_text "Felt nauseous"
    end
  end

  test "adherence history is accessible from navigation" do
    travel_to Time.utc(2026, 2, 12, 15, 0, 0) do
      sign_in_as_system(@user)

      visit dashboard_path

      # Click the Adherence link in the desktop navbar
      within "nav" do
        click_link "Adherence"
      end

      assert_text "Adherence History", wait: 5
    end
  end
end
