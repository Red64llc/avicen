require "test_helper"

# Integration tests for the complete registration-to-dashboard flow.
# These tests complement the existing dual_root_routing_test.rb by testing
# the full end-to-end flow from registration through profile setup to dashboard.
#
# Task 10.1 Requirements: 1.1, 1.4, 3.1, 3.2, 3.5, 4.1, 5.2, 5.6
class RegistrationToDashboardFlowTest < ActionDispatch::IntegrationTest
  # Test the complete registration-to-dashboard flow end-to-end
  # This is the primary integration test for the full user onboarding journey
  #
  # Requirements covered:
  #   - 1.1: Post-registration redirect to profile setup
  #   - 1.4: Save profile, redirect to dashboard
  #   - 3.2: Dashboard greets user by name
  #   - 3.5: Dashboard is after-auth redirect target
  #   - 5.2: Create account and start session
  #   - 5.6: Redirect to profile setup after registration
  test "complete registration to dashboard flow" do
    # Step 1: Register a new account
    get new_registration_path
    assert_response :success
    assert_select "h1", /Create an account/i

    # Step 2: Submit registration form
    assert_difference "User.count", 1 do
      post registration_path, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    # Step 3: Verify redirect to profile setup (5.6, 1.1)
    assert_redirected_to new_profile_path
    follow_redirect!
    assert_response :success
    assert_select "h1", /Complete Your Profile/i

    # Step 4: Submit profile form
    assert_difference "Profile.count", 1 do
      post profile_path, params: {
        profile: {
          name: "New User",
          date_of_birth: "1990-05-15",
          timezone: "Eastern Time (US & Canada)"
        }
      }
    end

    # Step 5: Verify redirect to dashboard with personalized greeting (1.4, 3.5)
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success

    # Verify personalized greeting (3.2)
    assert_select "h1", /Welcome back, New User/i
  end

  # Test that registration correctly creates an authenticated session
  # and allows immediate access to protected routes
  #
  # Requirement 5.2: Create account, start session
  test "registration creates authenticated session allowing access to protected routes" do
    post registration_path, params: {
      user: {
        email_address: "sessiontest@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    # After registration, user should be able to access authenticated routes
    # without being redirected to login
    get dashboard_path
    assert_response :success
    # No profile yet, so shows generic welcome
    assert_select "h1", /Welcome to Avicen/i
  end

  # Test registration flow with subsequent profile completion in a single session
  # This tests the continuity of the authenticated session through the flow
  test "registration session persists through profile creation" do
    # Register
    post registration_path, params: {
      user: {
        email_address: "persist@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    follow_redirect!

    # Create profile in the same session
    post profile_path, params: {
      profile: { name: "Persistent User" }
    }
    follow_redirect!

    # Session should still be active and show dashboard
    get root_path
    assert_response :success
    assert_match /Welcome back, Persistent User/i, response.body
  end

  # Test that the flow handles timezone setting correctly
  # Requirement 8.1: Store user's preferred timezone in profile
  test "registration flow saves timezone correctly" do
    # Register new user
    post registration_path, params: {
      user: {
        email_address: "timezone@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    follow_redirect!

    # Create profile with specific timezone
    post profile_path, params: {
      profile: {
        name: "Timezone User",
        timezone: "Pacific Time (US & Canada)"
      }
    }

    # Verify timezone was saved
    user = User.find_by(email_address: "timezone@example.com")
    assert_equal "Pacific Time (US & Canada)", user.profile.timezone
  end
end
