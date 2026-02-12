require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Register a custom Chrome driver with options to disable password manager popups
  Capybara.register_driver :headless_chrome_no_password_manager do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    # Use old headless mode for better compatibility with importmaps in CI
    # The new headless mode (--headless=new) has known issues with ES modules in some environments
    options.add_argument("--headless")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1400,900")
    # Disable password manager and related popups that interfere with tests
    options.add_argument("--disable-save-password-bubble")
    options.add_argument("--disable-features=PasswordLeakDetection,PasswordCheck,PasswordImport")
    options.add_argument("--disable-component-update")
    options.add_argument("--disable-sync")
    # Note: removed --disable-background-networking as it can interfere with ES module loading
    # Enable logging to capture JavaScript errors
    options.add_argument("--enable-logging=stderr")
    options.add_argument("--log-level=0")
    # Enable browser logging capability
    options.add_option("goog:loggingPrefs", { browser: "ALL" })
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

    # First, ensure document is fully loaded
    loop do
      ready = page.evaluate_script("document.readyState")
      break if ready == "complete"

      elapsed = Time.now - start_time
      if elapsed > 5
        raise "Document not ready after 5s. State: #{ready}"
      end
      sleep 0.1
    end

    # Now wait for Stimulus
    loop do
      ready = page.evaluate_script("typeof window.Stimulus !== 'undefined'")
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

        // Try to get importmap content
        let importmapContent = null;
        if (importmap) {
          try {
            importmapContent = JSON.parse(importmap.textContent);
          } catch (e) {
            importmapContent = 'parse_error';
          }
        }

        // Check module loader script content
        const moduleScript = document.querySelector('script[type="module"]');
        const moduleContent = moduleScript ? moduleScript.textContent.substring(0, 100) : null;

        return {
          scripts: scripts,
          hasImportmap: hasImportmap,
          turboLoaded: turboLoaded,
          stimulusLoaded: stimulusLoaded,
          documentReady: document.readyState,
          importmapContent: importmapContent,
          currentUrl: window.location.href,
          moduleContent: moduleContent
        };
      })()
    JS

    begin
      info = page.evaluate_script(diag_script)
      lines = [
        "JS Diagnostics:",
        "  Current URL: #{info['currentUrl']}",
        "  Document ready state: #{info['documentReady']}",
        "  Has importmap: #{info['hasImportmap']}",
        "  Turbo loaded: #{info['turboLoaded']}",
        "  Stimulus loaded: #{info['stimulusLoaded']}",
        "  Scripts found: #{info['scripts'].length}"
      ]
      info["scripts"].each do |s|
        lines << "    - #{s['type']}: #{s['src']}"
      end

      # Show first few importmap entries if available
      if info["importmapContent"].is_a?(Hash) && info["importmapContent"]["imports"]
        lines << "  Importmap entries (first 3):"
        info["importmapContent"]["imports"].first(3).each do |name, path|
          lines << "    - #{name}: #{path}"
        end

        # Try to check if assets are accessible
        asset_check = check_asset_accessibility(info["importmapContent"]["imports"])
        lines << "  Asset accessibility check:"
        asset_check.each { |line| lines << "    #{line}" }
      end

      # Capture browser console logs
      console_logs = collect_browser_logs
      unless console_logs.empty?
        lines << "  Browser console (errors/warnings):"
        console_logs.each { |log| lines << "    #{log}" }
      end

      # Show module script content for debugging
      if info["moduleContent"]
        lines << "  Module script content: #{info['moduleContent']}..."
      end

      lines.join("\n")
    rescue => e
      "JS Diagnostics failed: #{e.message}"
    end
  end

  # Collect browser console logs (errors and warnings)
  def collect_browser_logs
    logs = []
    begin
      browser_logs = page.driver.browser.logs.get(:browser)
      browser_logs.each do |entry|
        if %w[SEVERE WARNING].include?(entry.level)
          logs << "[#{entry.level}] #{entry.message}"
        end
      end
    rescue => e
      logs << "Could not collect browser logs: #{e.message}"
    end
    logs.take(10) # Limit to 10 entries
  end

  # Check if key assets are accessible via XMLHttpRequest (sync)
  def check_asset_accessibility(imports)
    results = []
    # Check a couple of key assets
    %w[@hotwired/turbo-rails @hotwired/stimulus application].each do |key|
      path = imports[key]
      next unless path

      check_script = <<~JS
        (function() {
          try {
            var xhr = new XMLHttpRequest();
            xhr.open('HEAD', '#{path}', false);
            xhr.send();
            return { status: xhr.status };
          } catch (e) {
            return { error: e.message };
          }
        })()
      JS

      begin
        result = page.evaluate_script(check_script)
        if result && result["status"] == 200
          results << "#{key}: OK (200)"
        elsif result && result["error"]
          results << "#{key}: ERROR - #{result['error']}"
        elsif result
          results << "#{key}: HTTP #{result['status']}"
        else
          results << "#{key}: Unknown result"
        end
      rescue => e
        results << "#{key}: Check failed - #{e.message}"
      end
    end
    results
  end
end
