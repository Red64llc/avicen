require "application_system_test_case"

# Task 12.3: System test verifying mobile-responsive navigation.
#
# Tests the medication navigation on a small viewport (320px width).
# Verifies all navigation links are accessible and the layout adapts correctly.
#
# Requirements: 11.1, 11.2
class MobileResponsiveNavigationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "mobile viewport at 320px shows hamburger menu and hides desktop navigation links" do
    sign_in_as_system(@user)
    visit dashboard_path

    # Resize to smallest supported mobile viewport (320px)
    page.driver.browser.manage.window.resize_to(320, 568)

    # Desktop navigation links should be hidden at this viewport
    assert_no_selector ".sm\\:flex .sm\\:space-x-8", visible: true

    # Hamburger menu button should be visible
    assert_selector "[data-action='click->nav-toggle#toggle']", visible: true

    # Mobile menu should be hidden initially
    assert_selector "#mobile-menu.hidden", visible: :hidden
  end

  test "mobile menu at 320px contains all medication navigation links" do
    sign_in_as_system(@user)
    visit dashboard_path

    # Resize to 320px mobile viewport
    page.driver.browser.manage.window.resize_to(320, 568)

    # Wait for Stimulus controller to connect (critical for CI)
    wait_for_stimulus_controller("nav-toggle")

    # Open the mobile menu
    assert_selector "[data-action='click->nav-toggle#toggle']", visible: true
    page.execute_script("document.querySelector('[data-action=\"click->nav-toggle#toggle\"]').click()")

    # Wait for menu to become visible
    assert_no_selector "#mobile-menu.hidden", wait: 5
    assert_selector "#mobile-menu", visible: true

    # Verify all medication navigation links are present (Req 11.1)
    within "#mobile-menu" do
      assert_link "Dashboard"
      assert_link "Daily Schedule"
      assert_link "Weekly Overview"
      assert_link "Prescriptions"
      assert_link "Adherence"
      assert_link "Settings"
      assert_button "Log out"
    end
  end

  test "mobile navigation links at 320px lead to correct pages" do
    sign_in_as_system(@user)
    visit dashboard_path

    # Resize to 320px
    page.driver.browser.manage.window.resize_to(320, 568)

    # Wait for Stimulus controller to connect (critical for CI)
    wait_for_stimulus_controller("nav-toggle")

    # Test Daily Schedule link
    page.execute_script("document.querySelector('[data-action=\"click->nav-toggle#toggle\"]').click()")
    assert_no_selector "#mobile-menu.hidden", wait: 5

    within "#mobile-menu" do
      click_link "Daily Schedule"
    end
    assert_text "Daily Schedule"

    # Test Prescriptions link
    page.driver.browser.manage.window.resize_to(320, 568)
    page.execute_script("document.querySelector('[data-action=\"click->nav-toggle#toggle\"]').click()")
    assert_no_selector "#mobile-menu.hidden", wait: 5

    within "#mobile-menu" do
      click_link "Prescriptions"
    end
    assert_text "Prescriptions"

    # Test Weekly Overview link
    page.driver.browser.manage.window.resize_to(320, 568)
    page.execute_script("document.querySelector('[data-action=\"click->nav-toggle#toggle\"]').click()")
    assert_no_selector "#mobile-menu.hidden", wait: 5

    within "#mobile-menu" do
      click_link "Weekly Overview"
    end
    # The weekly view should render
    assert_text "Weekly Schedule"

    # Test Adherence link
    page.driver.browser.manage.window.resize_to(320, 568)
    page.execute_script("document.querySelector('[data-action=\"click->nav-toggle#toggle\"]').click()")
    assert_no_selector "#mobile-menu.hidden", wait: 5

    within "#mobile-menu" do
      click_link "Adherence"
    end
    assert_text "Adherence History"
  end

  test "daily schedule view renders correctly at 320px viewport" do
    sign_in_as_system(@user)

    # Resize to 320px before visiting the page
    page.driver.browser.manage.window.resize_to(320, 568)

    visit schedule_path(date: "2026-02-12")

    # Verify the page renders and key elements are visible
    assert_text "Daily Schedule"

    # Date navigation controls should be visible
    assert_selector "[aria-label='Previous day']", visible: true
    assert_selector "[aria-label='Next day']", visible: true

    # Medication entries should be visible
    assert_text "Aspirin"

    # Quick-action buttons should be accessible
    assert_button "Taken" if has_text?("Pending")
  end

  test "prescriptions list renders correctly at 320px viewport" do
    sign_in_as_system(@user)

    page.driver.browser.manage.window.resize_to(320, 568)

    visit prescriptions_path

    # Verify prescriptions page renders
    assert_text "Prescriptions"

    # Prescription cards should be visible
    assert_text "Dr. Smith"
    assert_text "Dr. Johnson"

    # New Prescription button should be accessible
    assert_link "New Prescription"
  end

  test "prescription detail with medications renders correctly at 320px viewport" do
    sign_in_as_system(@user)

    page.driver.browser.manage.window.resize_to(320, 568)

    prescription = prescriptions(:one)
    visit prescription_path(prescription)

    # Verify prescription detail renders
    assert_text "Dr. Smith"
    assert_text "Medications"

    # Medications should be visible
    assert_text "Aspirin"
    assert_text "100mg"
  end

  test "adherence history page renders correctly at 320px viewport" do
    sign_in_as_system(@user)

    page.driver.browser.manage.window.resize_to(320, 568)

    visit adherence_path

    # Verify adherence page renders
    assert_text "Adherence History"
    assert_text "Overall Adherence"

    # Period selection buttons should be visible
    assert_link "7 days"
    assert_link "30 days"
    assert_link "90 days"
  end

  test "printable plan page renders correctly at 320px viewport" do
    sign_in_as_system(@user)

    page.driver.browser.manage.window.resize_to(320, 568)

    visit print_schedule_path

    # Verify printable plan renders
    assert_text "Medication Plan"

    # Print button should still be visible on mobile (only hidden when printing)
    assert_button "Print"

    # Active medications should be visible
    assert_text "Aspirin"
    assert_text "Ibuprofen"
  end
end
