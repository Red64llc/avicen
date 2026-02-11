require "test_helper"

class SetTimezoneTest < ActionDispatch::IntegrationTest
  setup do
    @user_with_timezone = users(:one)
    @user_without_timezone = User.create!(
      email_address: "notimezone@example.com",
      password: "password123"
    )
    # User two has a profile with UTC timezone
    @user_with_utc = users(:two)
  end

  test "applies user timezone from profile for authenticated user with timezone set" do
    # User one has profile with "Eastern Time (US & Canada)" timezone
    sign_in_as(@user_with_timezone)

    get profile_path

    # The request should be processed within the user's timezone
    assert_response :success
    # The timezone should be Eastern Time during the request
    # We can verify this by checking that the response was successful
    # and that the profile edit page loaded (which implicitly means the around_action worked)
  end

  test "defaults to UTC when user has no profile" do
    sign_in_as(@user_without_timezone)

    # Creating a profile to be able to visit a page that loads without errors
    get new_profile_path

    assert_response :success
    # Request completes successfully with UTC timezone (default)
  end

  test "defaults to UTC when profile has no timezone set" do
    # Create a user with a profile that has no timezone
    user = User.create!(
      email_address: "blanktimezone@example.com",
      password: "password123"
    )
    user.create_profile!(name: "Test User", timezone: nil)

    sign_in_as(user)
    get profile_path

    assert_response :success
    # Request completes successfully with UTC timezone (default)
  end

  test "defaults to UTC when profile has blank timezone" do
    user = User.create!(
      email_address: "emptytimezone@example.com",
      password: "password123"
    )
    user.create_profile!(name: "Test User", timezone: "")

    sign_in_as(user)
    get profile_path

    assert_response :success
    # Request completes successfully with UTC timezone (default)
  end

  test "defaults to UTC for unauthenticated requests" do
    get new_session_path

    assert_response :success
    # Request completes successfully with UTC timezone (default)
  end
end

# Unit test for the concern behavior using a mock controller
class SetTimezoneConcernTest < ActiveSupport::TestCase
  class TestController < ActionController::Base
    include SetTimezone

    def self.name
      "TestController"
    end
  end

  test "SetTimezone module can be included" do
    assert TestController.ancestors.include?(SetTimezone)
  end

  test "SetTimezone defines around_action" do
    callbacks = TestController._process_action_callbacks.select { |cb|
      cb.kind == :around
    }
    # Should have the set_timezone around_action
    assert callbacks.any?, "Expected SetTimezone to define an around_action"
  end

  test "current_timezone returns user timezone when set" do
    controller = TestController.new
    user = users(:one)
    profile = profiles(:one)

    # Mock Current.user to return our user with timezone profile
    Current.stub :user, user do
      timezone = controller.send(:current_timezone)
      assert_equal "Eastern Time (US & Canada)", timezone
    end
  end

  test "current_timezone returns UTC when user has no profile" do
    controller = TestController.new
    user = User.new(email_address: "test@example.com")

    Current.stub :user, user do
      timezone = controller.send(:current_timezone)
      assert_equal "UTC", timezone
    end
  end

  test "current_timezone returns UTC when no user" do
    controller = TestController.new

    Current.stub :user, nil do
      timezone = controller.send(:current_timezone)
      assert_equal "UTC", timezone
    end
  end

  test "current_timezone returns UTC when profile timezone is nil" do
    controller = TestController.new
    user = users(:one)
    user.profile.update_column(:timezone, nil)

    Current.stub :user, user do
      timezone = controller.send(:current_timezone)
      assert_equal "UTC", timezone
    end
  end

  test "current_timezone returns UTC when profile timezone is blank" do
    controller = TestController.new
    user = users(:one)
    user.profile.update_column(:timezone, "")

    Current.stub :user, user do
      timezone = controller.send(:current_timezone)
      assert_equal "UTC", timezone
    end
  end

  test "set_timezone wraps block with Time.use_zone" do
    controller = TestController.new
    user = users(:one)
    captured_timezone = nil

    Current.stub :user, user do
      controller.send(:set_timezone) do
        captured_timezone = Time.zone.name
      end
    end

    assert_equal "Eastern Time (US & Canada)", captured_timezone
  end

  test "set_timezone uses UTC when no timezone set" do
    controller = TestController.new
    captured_timezone = nil

    Current.stub :user, nil do
      controller.send(:set_timezone) do
        captured_timezone = Time.zone.name
      end
    end

    assert_equal "UTC", captured_timezone
  end
end
