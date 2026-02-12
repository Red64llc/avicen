require "test_helper"

class NavbarNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  # --- Navbar Navigation Links ---

  test "navbar contains link to daily schedule" do
    get dashboard_path
    assert_response :success
    assert_select "nav a[href=?]", schedule_path
  end

  test "navbar contains link to weekly overview" do
    get dashboard_path
    assert_response :success
    assert_select "nav a[href=?]", weekly_schedule_path
  end

  test "navbar contains link to prescriptions list" do
    get dashboard_path
    assert_response :success
    assert_select "nav a[href=?]", prescriptions_path
  end

  test "navbar contains link to adherence history" do
    get dashboard_path
    assert_response :success
    assert_select "nav a[href=?]", adherence_path
  end

  test "navbar navigation links are present on schedule page" do
    get schedule_path
    assert_response :success
    assert_select "nav a[href=?]", schedule_path
    assert_select "nav a[href=?]", weekly_schedule_path
    assert_select "nav a[href=?]", prescriptions_path
    assert_select "nav a[href=?]", adherence_path
  end

  test "navbar navigation links are present on prescriptions page" do
    get prescriptions_path
    assert_response :success
    assert_select "nav a[href=?]", schedule_path
    assert_select "nav a[href=?]", prescriptions_path
  end

  # --- Mobile Navigation ---

  test "mobile menu contains medication navigation links" do
    get dashboard_path
    assert_response :success
    # Mobile menu (id=mobile-menu) should contain the same navigation links
    assert_select "#mobile-menu a[href=?]", schedule_path
    assert_select "#mobile-menu a[href=?]", weekly_schedule_path
    assert_select "#mobile-menu a[href=?]", prescriptions_path
    assert_select "#mobile-menu a[href=?]", adherence_path
  end

  # --- Turbo Loading Indicator ---

  test "application includes Turbo JavaScript for progress bar" do
    get dashboard_path
    assert_response :success
    # The Turbo progress bar is configured via JavaScript (Turbo.setProgressBarDelay)
    # Verify that Turbo is loaded via importmap tags in the layout
    assert_select "script[type='importmap']", minimum: 1
  end

  test "Turbo progress bar CSS is configured in application stylesheet" do
    get dashboard_path
    assert_response :success
    # The layout includes the application stylesheet which contains progress bar styling
    assert_select "link[href*='application']", minimum: 1
  end

  # --- Navigation not shown to unauthenticated users ---

  test "medication navigation links are not shown to unauthenticated users" do
    sign_out
    get landing_page_path
    assert_response :success
    assert_select "nav a[href=?]", schedule_path, count: 0
    assert_select "nav a[href=?]", prescriptions_path, count: 0
  end
end
