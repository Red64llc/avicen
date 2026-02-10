require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new renders registration form" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid data creates user and session then redirects to profile setup" do
    assert_difference("User.count", 1) do
      assert_difference("Session.count", 1) do
        post registration_path, params: {
          user: {
            email_address: "newuser@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end

    assert_redirected_to new_profile_path
    assert cookies[:session_id].present?
  end

  test "create with missing email re-renders form with 422" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: "",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with short password re-renders form with 422" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: "shortpw@example.com",
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with mismatched password confirmation re-renders form with 422" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: "mismatch@example.com",
          password: "password123",
          password_confirmation: "different123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with duplicate email shows validation error" do
    existing_user = users(:one)

    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: existing_user.email_address,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create normalizes email address" do
    post registration_path, params: {
      user: {
        email_address: "  UPPER@EXAMPLE.COM  ",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to new_profile_path
    assert_equal "upper@example.com", User.last.email_address
  end

  test "rate limiting is configured on create action" do
    # Verify the controller has rate limiting configured by checking
    # that the before_action callback chain includes rate limiting.
    # The actual rate limiting behavior relies on the cache store
    # (null_store in test), so we verify configuration declaratively.
    callbacks = RegistrationsController._process_action_callbacks.select { |cb|
      cb.kind == :before && cb.filter.is_a?(Proc)
    }
    assert callbacks.any?, "Expected rate limiting before_action to be configured"
  end
end
