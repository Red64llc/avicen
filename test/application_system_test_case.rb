require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Register a custom Chrome driver with options to disable password manager popups
  Capybara.register_driver :headless_chrome_no_password_manager do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1400,900")
    # Disable password manager and related popups that interfere with tests
    options.add_argument("--disable-save-password-bubble")
    options.add_argument("--disable-features=PasswordLeakDetection,PasswordCheck,PasswordImport")
    options.add_argument("--disable-component-update")
    options.add_argument("--disable-sync")
    options.add_argument("--disable-background-networking")
    # Preferences to disable password manager
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
    options.add_preference("password_manager.leak_detection", false)
    options.add_preference("profile.default_content_setting_values.notifications", 2)
    options.add_preference("autofill.profile_enabled", false)

    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end

  driven_by :headless_chrome_no_password_manager

  # Allow localhost connections for Selenium/ChromeDriver communication
  WebMock.disable_net_connect!(allow_localhost: true)

  setup do
    # Reset viewport to desktop size before each test
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  def sign_in_as_system(user)
    visit new_session_path
    # Wait for the form to be ready before filling
    assert_field "Email address", wait: 5
    # Use find + fill_in with clear to ensure reliable input
    email_field = find_field("Email address")
    email_field.fill_in with: user.email_address
    password_field = find_field("Password")
    password_field.fill_in with: "password"
    click_on "Sign in"
    # Wait for login to complete by checking for authenticated UI elements
    # Using a positive assertion with wait ensures Capybara retries until the condition is met
    # Note: "Log out" is rendered via button_to (a form button), not a link
    assert_button "Log out", wait: 10
  end

  # Wait for Turbo to be ready (no pending requests).
  # Call this after page navigation to ensure Turbo Drive has finished processing.
  #
  # @param wait [Integer] Maximum seconds to wait (default: 5)
  def wait_for_turbo(wait: 5)
    Timeout.timeout(wait) do
      loop do
        turbo_ready = page.evaluate_script(<<~JS)
          (function() {
            // Check if Turbo is loaded
            if (typeof Turbo === 'undefined') return true;
            // Check if there are any pending frame requests
            const frames = document.querySelectorAll('turbo-frame[busy]');
            return frames.length === 0;
          })()
        JS
        break if turbo_ready
        sleep 0.1
      end
    end
  end

  # Wait for a Stimulus controller to be connected to an element.
  # This is necessary for CI environments where JS loading may be slower.
  #
  # @param controller_name [String] The Stimulus controller identifier (e.g., "nav-toggle")
  # @param selector [String] Optional CSS selector for the element (defaults to data-controller)
  # @param wait [Integer] Maximum seconds to wait (default: 5)
  def wait_for_stimulus_controller(controller_name, selector: nil, wait: 5)
    selector ||= "[data-controller*='#{controller_name}']"

    # Wait for the element to exist and for Stimulus to connect the controller
    assert_selector selector, wait: wait

    # Verify Stimulus has connected by checking the controller is registered
    result = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("#{selector.gsub('"', '\\"')}");
        if (!element) return false;
        if (!window.Stimulus) return false;
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "#{controller_name}");
        return controller !== null;
      })()
    JS

    # If not connected yet, wait and retry
    unless result
      Timeout.timeout(wait) do
        loop do
          sleep 0.1
          result = page.evaluate_script(<<~JS)
            (function() {
              const element = document.querySelector("#{selector.gsub('"', '\\"')}");
              if (!element) return false;
              if (!window.Stimulus) return false;
              const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "#{controller_name}");
              return controller !== null;
            })()
          JS
          break if result
        end
      end
    end
  end
end
