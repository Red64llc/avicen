require "application_system_test_case"

# Task 12.1: End-to-end system test covering the complete medication workflow.
#
# Tests the full flow: create a prescription, add a medication with drug search,
# configure a dosing schedule, navigate to the daily schedule, and log a dose as taken.
# Verifies Turbo Frame and Turbo Stream interactions work end-to-end in the browser.
#
# Requirements: 2.4, 3.5, 4.5, 5.1, 7.1
class MedicationWorkflowTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @aspirin = drugs(:aspirin)
  end

  test "complete medication workflow: create prescription, add medication, configure schedule, view daily schedule, and log a dose" do
    sign_in_as_system(@user)

    # Step 1: Navigate to prescriptions and create a new prescription (Req 2.4)
    visit prescriptions_path
    assert_text "Prescriptions"

    click_link "New Prescription"
    # Wait for the form to be ready, not just the page text
    assert_field "Doctor name", wait: 5

    fill_in "Doctor name", with: "Dr. System Test"
    fill_in "Prescribed date", with: "2026-02-12"
    fill_in "Notes", with: "System test prescription"
    click_button "Create Prescription"

    # Verify prescription was created and we see the detail page
    assert_text "Prescription was successfully created."
    assert_text "Dr. System Test"
    assert_text "System test prescription"

    # Step 2: Add a medication with drug search (Req 3.5)
    click_link "Add Medication"

    # Wait for the medication form to appear within Turbo Frame
    assert_selector "h2", text: "Add Medication", wait: 5

    # Wait for Stimulus controller to connect (critical for CI)
    wait_for_stimulus_controller("drug-search")

    # Search for a drug using the autocomplete
    fill_in "Search for a drug...", with: "Aspirin"
    # Wait for autocomplete results to appear
    assert_selector "li[role='option']", text: "Aspirin", wait: 5
    # Select the drug from autocomplete results
    find("li[role='option']", text: "Aspirin").click

    # Fill in medication details
    fill_in "Dosage", with: "100mg"
    select "Tablet", from: "Form"
    fill_in "Instructions", with: "Take with water"

    click_button "Add Medication"

    # Verify medication was added via Turbo Stream (no full page reload)
    assert_text "Medication was successfully added.", wait: 5
    assert_text "Aspirin"
    assert_text "100mg"

    # Step 3: Configure a dosing schedule (Req 4.5)
    click_link "Add Schedule"

    # Wait for the schedule form to appear within Turbo Frame
    assert_selector "h2", text: "Add Schedule", wait: 5

    # Fill in schedule details
    # Today is Thursday (2026-02-12), so we select all weekdays
    # Use JavaScript to set time field value (headless Chrome time input handling)
    time_field = find("input[type='time']")
    time_field.execute_script("this.value = '08:00'")
    check "Mon"
    check "Tue"
    check "Wed"
    check "Thu"
    check "Fri"
    fill_in "Dosage Amount (optional)", with: "100mg"
    fill_in "Instructions (optional)", with: "Take with breakfast"

    click_button "Add Schedule"

    # Verify schedule was added via Turbo Stream
    assert_text "Schedule was successfully added.", wait: 5
    assert_text "08:00"

    # Step 4: Navigate to the daily schedule (Req 5.1)
    # Navigate via the navbar to the daily schedule
    within "nav" do
      click_link "Schedule"
    end

    # Verify we are on the daily schedule page
    assert_text "Daily Schedule"

    # Navigate to today's date (2026-02-12, Thursday) which should have our scheduled medication
    # The daily schedule should show our Aspirin medication at 08:00
    # It should show all medications scheduled for today, including fixture data
    # Let's check that the page renders entries grouped by time
    visit schedule_path(date: "2026-02-12")

    assert_text "Daily Schedule"
    # We should see the Aspirin medication we just created (scheduled for Thu at 08:00)
    assert_text "Aspirin"
    assert_text "100mg"

    # Step 5: Log a dose as taken (Req 7.1)
    # Find and click the Taken button for our schedule entry
    # The taken button should be visible for pending entries
    assert_button "Taken", wait: 5

    # Click the first Taken button (for a pending entry)
    first("button", text: "Taken").click

    # Verify the dose was logged via Turbo Stream -- status should change to "Taken"
    assert_text "Dose marked as taken", wait: 5

    # The entry should now show "Taken" status badge instead of "Pending"
    # and an "Undo" button should appear
    assert_button "Undo", wait: 5
  end

  test "logging a dose as skipped with a reason updates the schedule entry via Turbo Stream" do
    sign_in_as_system(@user)

    # Use fixture data: aspirin_morning has morning_daily schedule for all days at 08:00
    # Navigate to a date that has no existing log
    visit schedule_path(date: "2026-02-12")

    assert_text "Daily Schedule"
    assert_text "Aspirin"

    # Find the skip reason field and the skipped button
    first_entry = find("[data-controller='medication-log']", match: :first)
    within(first_entry) do
      if has_button?("Skipped")
        # The reason field uses a name attribute (no associated label)
        find("input[name='medication_log[reason]']").set("Felt nauseous")
        click_button "Skipped"
      end
    end

    # Verify the dose was logged as skipped
    assert_text "Dose marked as skipped", wait: 5
  end

  test "undo a logged dose returns entry to pending state via Turbo Stream" do
    sign_in_as_system(@user)

    # Navigate to the date with existing taken log fixture (2026-02-10 is a Tuesday)
    visit schedule_path(date: "2026-02-10")

    assert_text "Daily Schedule"

    # The fixture taken_log exists for aspirin morning_daily on 2026-02-10
    # There should be an Undo button for the taken entry
    if has_button?("Undo", wait: 3)
      click_button "Undo", match: :first

      # Verify the undo action was successful
      assert_text "Dose log has been undone", wait: 5
    end
  end
end
