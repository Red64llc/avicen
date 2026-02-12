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
    # Enable logging to capture JavaScript errors
    options.add_argument("--enable-logging")
    options.add_argument("--v=1")
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
    wait_for_javascript_ready
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    # Wait for login to complete by checking for authenticated UI elements
    # Note: "Log out" is rendered via button_to (a form button), not a link
    assert_button "Log out", wait: 5
    wait_for_javascript_ready
  end

  # Wait for JavaScript to be fully loaded and ready
  # This ensures importmaps have been processed and Stimulus is available
  def wait_for_javascript_ready(wait: 15)
    start_time = Time.now
    loop do
      ready = page.evaluate_script(<<~JS)
        document.readyState === 'complete' && typeof window.Stimulus !== 'undefined'
      JS
      return true if ready

      elapsed = Time.now - start_time
      if elapsed > wait
        # Don't raise here, just return - some pages might not have Stimulus
        return false
      end

      sleep 0.2
    end
  end

  # Wait for a Stimulus controller to be connected to an element.
  # This is necessary for CI environments where JS loading may be slower.
  #
  # @param controller_name [String] The Stimulus controller identifier (e.g., "nav-toggle")
  # @param selector [String] Optional CSS selector for the element (defaults to data-controller)
  # @param wait [Integer] Maximum seconds to wait (default: 20)
  def wait_for_stimulus_controller(controller_name, selector: nil, wait: 20)
    selector ||= "[data-controller*='#{controller_name}']"

    # First, wait for the page and Stimulus framework to be ready
    # This is critical in CI where JS loading can be slow
    wait_for_stimulus_framework(wait: wait)

    # Wait for the element to exist
    assert_selector selector, wait: wait

    # Now wait for the specific controller to be connected
    start_time = Time.now
    check_script = <<~JS
      (function() {
        const element = document.querySelector("#{selector.gsub('"', '\\"')}");
        if (!element) return { ready: false, reason: 'element_not_found' };
        if (typeof window.Stimulus === 'undefined') return { ready: false, reason: 'stimulus_not_loaded' };
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "#{controller_name}");
        return { ready: controller !== null, reason: controller ? 'connected' : 'controller_not_connected' };
      })()
    JS

    loop do
      result = page.evaluate_script(check_script)
      return true if result && result["ready"]

      elapsed = Time.now - start_time
      if elapsed > wait
        reason = result ? result["reason"] : "unknown"
        # Collect diagnostic info when failing
        diag = collect_js_diagnostics
        raise "Stimulus controller '#{controller_name}' not ready after #{wait}s. Reason: #{reason}\n#{diag}"
      end

      sleep 0.2
    end
  end

  # Wait for the Stimulus framework itself to be loaded
  # This waits for document ready and window.Stimulus to be defined
  def wait_for_stimulus_framework(wait: 20)
    start_time = Time.now
    loop do
      ready = page.evaluate_script(<<~JS)
        document.readyState === 'complete' && typeof window.Stimulus !== 'undefined'
      JS
      return true if ready

      elapsed = Time.now - start_time
      if elapsed > wait
        diag = collect_js_diagnostics
        raise "Stimulus framework not loaded after #{wait}s.\n#{diag}"
      end

      sleep 0.2
    end
  end

  # Collect diagnostic information about JavaScript loading state
  def collect_js_diagnostics
    diag_script = <<~JS
      (function() {
        const scripts = Array.from(document.querySelectorAll('script[type="importmap"], script[type="module"]'))
          .map(s => ({ type: s.type, src: s.src || '(inline)' }));
        const importmap = document.querySelector('script[type="importmap"]');
        const hasImportmap = !!importmap;
        const turboLoaded = typeof window.Turbo !== 'undefined';
        const stimulusLoaded = typeof window.Stimulus !== 'undefined';

        return {
          scripts: scripts,
          hasImportmap: hasImportmap,
          turboLoaded: turboLoaded,
          stimulusLoaded: stimulusLoaded,
          documentReady: document.readyState
        };
      })()
    JS

    begin
      info = page.evaluate_script(diag_script)
      lines = [
        "JS Diagnostics:",
        "  Document ready state: #{info['documentReady']}",
        "  Has importmap: #{info['hasImportmap']}",
        "  Turbo loaded: #{info['turboLoaded']}",
        "  Stimulus loaded: #{info['stimulusLoaded']}",
        "  Scripts found: #{info['scripts'].length}"
      ]
      info["scripts"].each do |s|
        lines << "    - #{s['type']}: #{s['src']}"
      end
      lines.join("\n")
    rescue => e
      "JS Diagnostics failed: #{e.message}"
    end
  end
end
