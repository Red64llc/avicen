require "test_helper"

class AuthenticatedConstraintTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @session = @user.sessions.create!(user_agent: "Test Agent", ip_address: "127.0.0.1")
  end

  test "matches? returns true when valid session cookie exists" do
    request = mock_request_with_session(@session.id)
    assert AuthenticatedConstraint.matches?(request)
  end

  test "matches? returns false when no session cookie exists" do
    request = mock_request_without_session
    assert_not AuthenticatedConstraint.matches?(request)
  end

  test "matches? returns false when session cookie has invalid id" do
    request = mock_request_with_session(999999)
    assert_not AuthenticatedConstraint.matches?(request)
  end

  test "matches? returns false when session has been deleted" do
    session_id = @session.id
    @session.destroy
    request = mock_request_with_session(session_id)
    assert_not AuthenticatedConstraint.matches?(request)
  end

  private

  def mock_request_with_session(session_id)
    request = ActionDispatch::TestRequest.create
    request.cookie_jar.signed[:session_id] = session_id
    request
  end

  def mock_request_without_session
    ActionDispatch::TestRequest.create
  end
end
