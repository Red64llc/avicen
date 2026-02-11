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
end
