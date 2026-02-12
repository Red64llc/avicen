require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  # Allow localhost connections for Selenium/ChromeDriver communication
  WebMock.disable_net_connect!(allow_localhost: true)

  setup do
    # Reset viewport to desktop size before each test
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  def sign_in_as_system(user)
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    # Wait for login to complete by checking we're no longer on the sign-in page
    assert_no_current_path new_session_path
  end
end
