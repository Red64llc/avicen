require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  setup do
    @user_with_profile = users(:one)
  end

  test "mobile menu toggle shows and hides navigation" do
    sign_in_as_system(@user_with_profile)
    visit dashboard_path

    # Wait for Stimulus controller to connect BEFORE resizing (critical for CI)
    # The controller must be connected at desktop size first
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

    # Click again to close
    page.execute_script("document.querySelector('[data-action=\"click->nav-toggle#toggle\"]').click()")

    # Mobile menu should be hidden again
    assert_selector "#mobile-menu.hidden", visible: :hidden, wait: 5
  end

  test "navigation shows dashboard and settings links when authenticated" do
    sign_in_as_system(@user_with_profile)
    visit dashboard_path

    within "nav" do
      assert_link "Dashboard"
      assert_link "Settings"
      assert_button "Log out"
    end
  end

  test "navigation shows user name when profile exists" do
    sign_in_as_system(@user_with_profile)
    visit dashboard_path

    within "nav" do
      assert_text @user_with_profile.profile.name
    end
  end

  test "navigation shows sign in and get started when unauthenticated" do
    visit root_path

    within "nav" do
      assert_link "Sign In"
      assert_link "Get Started"
    end
  end

  test "navigation shows Biology Reports link when authenticated" do
    sign_in_as_system(@user_with_profile)
    visit dashboard_path

    within "nav" do
      assert_link "Biology Reports", href: biology_reports_path
    end
  end

  test "Biology Reports link navigates to biology reports index" do
    sign_in_as_system(@user_with_profile)
    visit dashboard_path

    within "nav" do
      click_link "Biology Reports"
    end

    assert_current_path biology_reports_path
    assert_text "Biology Reports"
  end
end
