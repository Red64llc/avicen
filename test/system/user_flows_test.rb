require "application_system_test_case"

# System tests for user-facing flows.
# These tests use a browser to verify the UI works correctly from a user's perspective.
#
# Note: Navigation-specific tests are in test/system/navigation_test.rb
# This file focuses on user flows (registration, login, landing page interaction).
#
# Task 10.2 Requirements: 3.2, 4.2, 4.3, 4.4, 5.1, 5.2, 6.1, 6.5
class UserFlowsTest < ApplicationSystemTestCase
  # Requirement 4.2: Landing page displays app description
  # Requirement 4.3: Landing page has login link (functional)
  # Requirement 4.4: Landing page has registration link (functional)
  test "landing page displays app description and has functional auth links" do
    visit root_path

    # Verify app description is visible (4.2)
    assert_text "Avicen"
    assert_text "health management"
    assert_text "wellness"

    # Verify login link is functional (4.3)
    # Use within to target navbar link (there's also a Sign In in the hero section)
    within "nav" do
      assert_link "Sign In"
      click_link "Sign In"
    end
    assert_current_path new_session_path
    assert_text "Sign in"

    # Go back and verify registration link is functional (4.4)
    visit root_path
    # Use within to target navbar link (there's also a Get Started in the hero section)
    within "nav" do
      assert_link "Get Started"
      click_link "Get Started"
    end
    assert_current_path new_registration_path
    assert_text "Create an account"
  end

  # Requirement 5.1: Registration page accessible without auth
  # Requirement 5.2: Create account and start session
  test "registration form fill and submit redirects to profile setup" do
    visit new_registration_path

    assert_selector "h1", text: /Create an account/i

    # Fill in registration form fields
    fill_in "Email address", with: "systemtest@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    click_button "Create account"

    # Should redirect to profile setup page (5.2, 5.6)
    assert_current_path new_profile_path
    assert_selector "h1", text: /Complete Your Profile/i
    assert_text "Tell us a little about yourself"
  end

  # Requirement 3.2: Dashboard displays personalized greeting after login
  test "dashboard displays personalized greeting after login" do
    user = users(:one)

    # Use the sign_in_as_system helper for consistent login
    sign_in_as_system(user)

    # Should be on dashboard with personalized greeting (3.2)
    assert_current_path root_path
    assert_selector "h1", text: /Welcome back, #{user.profile.name}/i
    assert_text "Your Dashboard"
  end

  # Test the complete registration to profile setup flow via browser UI
  # This is the primary end-to-end system test for the user onboarding journey
  test "complete registration through profile setup via UI" do
    visit new_registration_path

    # Fill in registration form
    fill_in "Email address", with: "fullflow@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    click_button "Create account"

    # Should be on profile setup page
    assert_current_path new_profile_path

    # Fill in profile form
    fill_in "Name", with: "Full Flow User"
    fill_in "Date of birth", with: "1985-03-20"
    select "Eastern Time (US & Canada)", from: "Timezone"

    click_button "Create Profile"

    # Should redirect to dashboard with personalized greeting
    assert_current_path root_path
    assert_selector "h1", text: /Welcome back, Full Flow User/i
    assert_text "Profile created successfully"
  end

  # Requirement 6.1: Responsive navigation
  # Requirement 6.5: Mobile-first responsive layout
  # Tests that hamburger menu toggle is functional on mobile viewport
  # Complements navigation_test.rb with additional verification of mobile menu content
  test "hamburger menu toggle shows navigation links on mobile" do
    user = users(:one)
    sign_in_as_system(user)

    visit dashboard_path

    # Wait for Stimulus controller to connect BEFORE resizing (critical for CI)
    wait_for_stimulus_controller("nav-toggle")

    # Resize to mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)

    # Wait for hamburger button to be visible after resize
    assert_selector "[data-action='click->nav-toggle#toggle']", visible: true

    # Mobile menu should be hidden initially
    assert_selector "#mobile-menu.hidden", visible: :hidden

    # Click hamburger button to open menu using JavaScript for reliability
    page.execute_script("document.querySelector('[data-action=\"click->nav-toggle#toggle\"]').click()")

    # Wait for menu to become visible (check that hidden class is removed)
    assert_no_selector "#mobile-menu.hidden", wait: 5
    assert_selector "#mobile-menu", visible: true

    within "#mobile-menu" do
      assert_link "Dashboard"
      assert_link "Settings"
      assert_button "Log out"
    end

    # Click again to close
    page.execute_script("document.querySelector('[data-action=\"click->nav-toggle#toggle\"]').click()")

    # Mobile menu should be hidden again
    assert_selector "#mobile-menu.hidden", visible: :hidden, wait: 5
  end

  # Test the unauthenticated mobile navigation shows correct auth links
  test "mobile navigation shows auth links when unauthenticated" do
    visit root_path

    # Wait for Stimulus controller to connect BEFORE resizing (critical for CI)
    wait_for_stimulus_controller("nav-toggle")

    # Resize to mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)

    # Wait for hamburger button to be visible after resize
    assert_selector "[data-action='click->nav-toggle#toggle']", visible: true

    # Mobile menu should be hidden initially
    assert_selector "#mobile-menu.hidden", visible: :hidden

    # Open mobile menu using JavaScript for reliability
    page.execute_script("document.querySelector('[data-action=\"click->nav-toggle#toggle\"]').click()")

    # Wait for menu to become visible (check that hidden class is removed)
    assert_no_selector "#mobile-menu.hidden", wait: 5
    assert_selector "#mobile-menu", visible: true

    within "#mobile-menu" do
      assert_link "Sign In"
      assert_link "Get Started"
    end
  end
end
