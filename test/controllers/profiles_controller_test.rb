require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_with_profile = users(:one)
    @user_without_profile = users(:two)
    # Remove the profile from user two for tests that need a user without a profile
    profiles(:two).destroy
  end

  # Test authentication requirement
  test "new requires authentication" do
    get new_profile_path
    assert_redirected_to new_session_path
  end

  test "create requires authentication" do
    post profile_path, params: { profile: { name: "Test" } }
    assert_redirected_to new_session_path
  end

  test "edit requires authentication" do
    get edit_profile_path
    assert_redirected_to new_session_path
  end

  test "update requires authentication" do
    patch profile_path, params: { profile: { name: "Updated" } }
    assert_redirected_to new_session_path
  end

  # Test new action
  test "new renders profile setup form for authenticated user without profile" do
    sign_in_as(@user_without_profile)

    get new_profile_path
    assert_response :success
    assert_select "form[action=?]", profile_path
    assert_select "input[name='profile[name]']"
    assert_select "select[name='profile[timezone]']"
  end

  # Test create action - success
  test "create with valid data creates profile and redirects to dashboard with notice" do
    sign_in_as(@user_without_profile)

    assert_difference("Profile.count", 1) do
      post profile_path, params: {
        profile: {
          name: "New User",
          date_of_birth: "1985-06-15",
          timezone: "Pacific Time (US & Canada)"
        }
      }
    end

    assert_redirected_to root_path
    assert_equal "Profile created successfully.", flash[:notice]

    profile = @user_without_profile.reload.profile
    assert_equal "New User", profile.name
    assert_equal Date.new(1985, 6, 15), profile.date_of_birth
    assert_equal "Pacific Time (US & Canada)", profile.timezone
  end

  test "create scopes profile to current user" do
    sign_in_as(@user_without_profile)

    post profile_path, params: {
      profile: { name: "Scoped User" }
    }

    assert_equal @user_without_profile.id, Profile.last.user_id
  end

  # Test create action - validation failure
  test "create with missing name re-renders form with 422" do
    sign_in_as(@user_without_profile)

    assert_no_difference("Profile.count") do
      post profile_path, params: {
        profile: { name: "", timezone: "UTC" }
      }
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?]", profile_path
  end

  # Test edit action
  test "edit renders current profile in editable form" do
    sign_in_as(@user_with_profile)

    get edit_profile_path
    assert_response :success
    assert_select "form[action=?]", profile_path
    assert_select "input[name='profile[name]'][value=?]", @user_with_profile.profile.name
    assert_select "turbo-frame#profile_form"
  end

  test "edit retrieves only the current user's profile" do
    sign_in_as(@user_with_profile)

    get edit_profile_path
    assert_response :success

    # The form should show the current user's profile data
    assert_select "input[name='profile[name]'][value=?]", "User One"
  end

  # Test update action - success
  test "update with valid data saves changes and redirects with success notice" do
    sign_in_as(@user_with_profile)

    patch profile_path, params: {
      profile: {
        name: "Updated Name",
        timezone: "Mountain Time (US & Canada)"
      }
    }

    assert_redirected_to edit_profile_path
    assert_equal "Profile updated successfully.", flash[:notice]

    @user_with_profile.reload
    assert_equal "Updated Name", @user_with_profile.profile.name
    assert_equal "Mountain Time (US & Canada)", @user_with_profile.profile.timezone
  end

  test "update responds with Turbo Stream for turbo stream requests" do
    sign_in_as(@user_with_profile)

    patch profile_path,
      params: { profile: { name: "Turbo Updated" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match(/turbo-stream/, response.content_type)

    @user_with_profile.reload
    assert_equal "Turbo Updated", @user_with_profile.profile.name
  end

  # Test update action - validation failure
  test "update with missing name re-renders form with 422" do
    sign_in_as(@user_with_profile)

    patch profile_path, params: {
      profile: { name: "" }
    }

    assert_response :unprocessable_entity
    assert_select "form[action=?]", profile_path
  end

  # Test profile access scoping
  test "profile access is scoped exclusively to authenticated user" do
    # Sign in as user one
    sign_in_as(@user_with_profile)

    # Update should only affect the current user's profile
    original_user_one_name = @user_with_profile.profile.name

    patch profile_path, params: {
      profile: { name: "My New Name" }
    }

    @user_with_profile.reload
    assert_equal "My New Name", @user_with_profile.profile.name

    # Verify the profile belongs to the current user
    assert_equal @user_with_profile.id, @user_with_profile.profile.user_id
  end

  test "cannot access another user's profile via edit" do
    # User one has a profile, sign in as user one
    sign_in_as(@user_with_profile)

    get edit_profile_path
    assert_response :success

    # The profile shown should be the current user's profile, not any other user's
    assert_select "input[name='profile[name]'][value=?]", @user_with_profile.profile.name
  end

  # Test strong parameters
  test "only permitted params are accepted" do
    sign_in_as(@user_without_profile)

    post profile_path, params: {
      profile: {
        name: "Test User",
        date_of_birth: "1990-01-01",
        timezone: "UTC",
        user_id: 999  # Should be ignored
      }
    }

    assert_redirected_to root_path
    assert_equal @user_without_profile.id, Profile.last.user_id
    assert_not_equal 999, Profile.last.user_id
  end
end
