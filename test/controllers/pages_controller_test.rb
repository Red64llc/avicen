require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders landing page for unauthenticated user" do
    get landing_page_path
    assert_response :success
  end

  test "home does not require authentication" do
    get landing_page_path
    assert_response :success
    # Should not redirect to login
    assert_not_equal new_session_path, response.redirect_url
  end

  test "landing page includes application description" do
    get landing_page_path
    assert_response :success
    assert_match /Avicen/i, response.body
    assert_match /health/i, response.body
  end

  test "landing page has visible link to login page" do
    get landing_page_path
    assert_response :success
    assert_select "a[href=?]", new_session_path
  end

  test "landing page has visible link to registration page" do
    get landing_page_path
    assert_response :success
    assert_select "a[href=?]", new_registration_path
  end

  test "unauthenticated user sees landing page at root path" do
    get root_path
    assert_response :success
    # Verify it's the landing page content
    assert_match /Avicen/i, response.body
    assert_select "a[href=?]", new_session_path
    assert_select "a[href=?]", new_registration_path
  end
end
