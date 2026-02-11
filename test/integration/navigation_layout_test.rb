require "test_helper"

class NavigationLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @user_with_profile = users(:one)
    @user_without_profile = users(:two)
    profiles(:two).destroy
  end

  test "authenticated pages include navigation with dashboard link" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
    assert_select "nav[role='navigation']"
    assert_select "a[href='#{dashboard_path}']"
  end

  test "authenticated pages include navigation with settings link" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
    assert_select "a[href='#{edit_profile_path}']"
  end

  test "authenticated pages include logout button" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
    assert_select "button", text: /Log out/i
  end

  test "authenticated user sees their name in navigation when profile exists" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
    assert_match @user_with_profile.profile.name, response.body
  end

  test "authenticated user sees their email in navigation when no profile" do
    sign_in_as(@user_without_profile)
    get dashboard_path
    assert_response :success
    assert_match @user_without_profile.email_address, response.body
  end

  test "landing page includes navigation" do
    get root_path
    assert_response :success
    assert_select "nav[role='navigation']"
  end

  test "landing page navigation shows login and signup links" do
    get root_path
    assert_response :success
    assert_select "a[href='#{new_session_path}']"
    assert_select "a[href='#{new_registration_path}']"
  end

  test "landing page navigation does not show dashboard link" do
    get root_path
    assert_response :success
    # Dashboard link should not be in nav for unauthenticated users
    assert_select "nav a[href='#{dashboard_path}']", count: 0
  end

  test "navigation includes mobile menu toggle" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
    assert_select "[data-controller='nav-toggle']"
    assert_select "button[data-action*='nav-toggle#toggle']"
  end

  test "profile edit page includes navigation" do
    sign_in_as(@user_with_profile)
    get edit_profile_path
    assert_response :success
    assert_select "nav[role='navigation']"
  end

  # Task 6.3: Application layout structure tests
  test "application layout has responsive main container" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
    # Verify main element exists with responsive container classes (mobile-first approach)
    # The main element should have: container mx-auto px-4 sm:px-6 lg:px-8 py-8
    assert_select "main.container"
    main_element = css_select("main").first
    assert main_element, "Expected main element to exist"
    main_classes = main_element["class"]
    assert_includes main_classes, "px-4", "Expected mobile-first base padding class"
    assert_includes main_classes, "sm:px-6", "Expected small breakpoint padding class"
    assert_includes main_classes, "lg:px-8", "Expected large breakpoint padding class"
  end

  test "application layout body has minimum height styling" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
    # Body should have min-h-screen for full-height layout
    body_element = css_select("body").first
    assert body_element, "Expected body element to exist"
    body_classes = body_element["class"]
    assert_includes body_classes, "min-h-screen", "Expected min-h-screen class on body"
  end

  test "application layout has proper structure with nav and main" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
    # Verify proper document structure: body contains nav followed by main
    assert_select "body" do
      assert_select "nav", count: 1
      assert_select "main", count: 1
    end
  end

  test "unauthenticated layout has same responsive structure" do
    get root_path
    assert_response :success
    # Verify layout structure is consistent for unauthenticated pages
    body_element = css_select("body").first
    assert body_element, "Expected body element to exist"
    assert_includes body_element["class"], "min-h-screen"

    main_element = css_select("main").first
    assert main_element, "Expected main element to exist"
    assert_includes main_element["class"], "px-4"
  end
end
