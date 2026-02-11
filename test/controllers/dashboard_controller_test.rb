require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_with_profile = users(:one)
    @user_without_profile = users(:two)
    # Remove profile from user two to test profile completion prompt
    profiles(:two).destroy
  end

  test "show requires authentication" do
    get dashboard_path
    assert_redirected_to new_session_path
  end

  test "show renders dashboard for authenticated user" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
  end

  test "show greets user by name when profile with name exists" do
    sign_in_as(@user_with_profile)
    get dashboard_path
    assert_response :success
    assert_select "h1", /User One/
  end

  test "show displays profile completion prompt when no profile exists" do
    sign_in_as(@user_without_profile)
    get dashboard_path
    assert_response :success
    assert_select "a[href=?]", new_profile_path
    assert_match /complete your profile/i, response.body
  end

  test "dashboard is accessible at root path for authenticated users" do
    sign_in_as(@user_with_profile)
    get root_path
    assert_response :success
    assert_select "h1", /User One/
  end
end
