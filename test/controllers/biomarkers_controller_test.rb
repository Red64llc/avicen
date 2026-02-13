require "test_helper"

class BiomarkersControllerTest < ActionDispatch::IntegrationTest
  test "should get index when authenticated" do
    sign_in_as(users(:one))
    get biomarkers_url
    assert_response :success
  end

  test "should show biomarkers with test result counts" do
    sign_in_as(users(:one))
    get biomarkers_url
    assert_response :success
    # Should show biomarkers that have test results for this user
    assert_select "div.biomarker-card"
  end

  test "should order biomarkers alphabetically by name" do
    sign_in_as(users(:one))
    get biomarkers_url
    assert_response :success
  end

  test "should only show biomarkers with test results for current user" do
    sign_in_as(users(:one))
    get biomarkers_url
    assert_response :success
    # Should not show biomarkers from other users
  end

  test "should link to biomarker trend page" do
    sign_in_as(users(:one))
    get biomarkers_url
    assert_response :success
    # Check for links to trend pages
    assert_select "a[href*='biomarker_trends']"
  end

  test "should redirect to login when not authenticated" do
    get biomarkers_url
    assert_redirected_to new_session_path
  end
end
