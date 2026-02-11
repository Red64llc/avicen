require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  setup do
    @user_without_profile = User.create!(
      email_address: "noprofile@example.com",
      password: "password123"
    )
  end

  test "valid profile with all attributes" do
    profile = Profile.new(
      user: @user_without_profile,
      name: "Test User",
      date_of_birth: Date.new(1990, 1, 15),
      timezone: "Eastern Time (US & Canada)"
    )
    assert profile.valid?
  end

  test "validates name presence" do
    profile = Profile.new(user: @user_without_profile, name: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:name], "can't be blank"
  end

  test "validates name is not blank string" do
    profile = Profile.new(user: @user_without_profile, name: "")
    assert_not profile.valid?
    assert_includes profile.errors[:name], "can't be blank"
  end

  test "validates timezone inclusion in ActiveSupport::TimeZone names when present" do
    profile = Profile.new(user: @user_without_profile, name: "Test", timezone: "Invalid/Timezone")
    assert_not profile.valid?
    assert_includes profile.errors[:timezone], "is not included in the list"
  end

  test "allows valid timezone" do
    profile = Profile.new(user: @user_without_profile, name: "Test", timezone: "UTC")
    assert profile.valid?
  end

  test "allows nil timezone" do
    profile = Profile.new(user: @user_without_profile, name: "Test", timezone: nil)
    assert profile.valid?
  end

  test "allows blank timezone" do
    profile = Profile.new(user: @user_without_profile, name: "Test", timezone: "")
    assert profile.valid?
  end

  test "belongs to user" do
    profile = profiles(:one)
    assert_instance_of User, profile.user
    assert_equal users(:one), profile.user
  end

  test "rejects duplicate user_id" do
    existing_profile = profiles(:one)
    duplicate = Profile.new(
      user: existing_profile.user,
      name: "Another Name"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "date_of_birth is optional" do
    profile = Profile.new(user: @user_without_profile, name: "Test", date_of_birth: nil)
    assert profile.valid?
  end
end
