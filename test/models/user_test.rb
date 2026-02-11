require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "validates email_address presence" do
    user = User.new(email_address: nil, password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "validates email_address uniqueness case-insensitively" do
    existing = users(:one)
    user = User.new(
      email_address: existing.email_address.upcase,
      password: "password123"
    )
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "validates password minimum length of 8 characters" do
    user = User.new(email_address: "new@example.com", password: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "accepts password with 8 or more characters" do
    user = User.new(email_address: "new@example.com", password: "password123")
    assert user.valid?
  end

  test "does not validate password length when password is not being set" do
    user = users(:one)
    # Reload from database - password will be nil (only digest is stored)
    user.reload
    assert user.valid?
  end

  test "has_one profile association" do
    user = users(:one)
    assert_respond_to user, :profile
    assert_instance_of Profile, user.profile
  end

  test "dependent destroy removes profile when user is destroyed" do
    user = users(:one)
    profile = user.profile
    assert_not_nil profile

    assert_difference("Profile.count", -1) do
      user.destroy
    end
  end

  test "preserves has_secure_password behavior" do
    user = User.new(email_address: "test@example.com", password: "password123")
    assert user.authenticate("password123")
    assert_not user.authenticate("wrongpassword")
  end

  test "preserves email normalization" do
    user = User.new(email_address: "  TEST@EXAMPLE.COM  ", password: "password123")
    assert_equal "test@example.com", user.email_address
  end
end
