require "test_helper"

class DualRootRoutingTest < ActionDispatch::IntegrationTest
  setup do
    @user_with_profile = users(:one)
    @user_without_profile = users(:two)
    # Remove profile from user two to test profile completion prompt
    profiles(:two).destroy
  end

  # Requirement 3.1: Authenticated user sees dashboard at root path
  test "authenticated user sees dashboard at root path" do
    sign_in_as(@user_with_profile)
    get root_path
    assert_response :success
    # Verify it's the dashboard (shows greeting)
    assert_select "h1", /User One/
  end

  # Requirement 3.2: Dashboard greets user by name
  test "authenticated user sees personalized greeting on dashboard" do
    sign_in_as(@user_with_profile)
    get root_path
    assert_response :success
    assert_match /Welcome back, User One/i, response.body
  end

  # Requirement 3.3: Dashboard shows profile completion prompt when no profile
  test "dashboard shows profile completion prompt when no profile exists" do
    sign_in_as(@user_without_profile)
    get root_path
    assert_response :success
    assert_match /complete your profile/i, response.body
    assert_select "a[href=?]", new_profile_path
  end

  # Requirement 3.4: Dashboard requires authentication
  test "dashboard requires authentication" do
    get dashboard_path
    assert_redirected_to new_session_path
  end

  # Requirement 4.1: Unauthenticated user sees landing page at root path
  test "unauthenticated user sees landing page at root path" do
    get root_path
    assert_response :success
    # Verify it's the landing page (shows app description)
    assert_match /Avicen/i, response.body
    assert_match /health management/i, response.body
  end

  # Requirement 4.2: Landing page includes description
  test "landing page includes application description" do
    get root_path
    assert_response :success
    assert_match /Avicen/i, response.body
    assert_match /health/i, response.body
  end

  # Requirement 4.3: Landing page has login link
  test "landing page has login link" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_session_path
  end

  # Requirement 4.4: Landing page has registration link
  test "landing page has registration link" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_registration_path
  end

  # Requirement 4.5: Unauthenticated access to landing page
  test "unauthenticated user can access landing page without being redirected to login" do
    get landing_page_path
    assert_response :success
    # Should not be redirected
    assert_not response.redirect?
  end

  # Requirement 4.6: Authenticated user is implicitly redirected from landing to dashboard
  # This is enforced by the AuthenticatedConstraint at the routing layer.
  # When an authenticated user visits the root path, they are routed to the dashboard
  # instead of the landing page.
  test "authenticated user visiting root path sees dashboard not landing page" do
    sign_in_as(@user_with_profile)
    get root_path
    assert_response :success
    # Should see dashboard content (greeting), not landing page content
    assert_select "h1", /User One/
    # Should not see landing page elements
    assert_select "a[href=?]", new_registration_path, count: 0
  end
end
