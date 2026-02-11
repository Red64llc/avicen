require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  # Task 7.1: PWA Manifest Tests (Requirements: 2.1, 2.2, 2.3, 2.6, 2.7, 2.8)

  test "manifest route serves valid JSON at /manifest.json" do
    get pwa_manifest_path(format: :json)
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "manifest contains correct app name" do
    get pwa_manifest_path(format: :json)
    manifest = JSON.parse(response.body)
    assert_equal "Avicen", manifest["name"]
  end

  test "manifest contains standalone display mode" do
    get pwa_manifest_path(format: :json)
    manifest = JSON.parse(response.body)
    assert_equal "standalone", manifest["display"]
  end

  test "manifest contains appropriate theme and background colors (not placeholder red)" do
    get pwa_manifest_path(format: :json)
    manifest = JSON.parse(response.body)

    # Theme and background colors should be set to appropriate values, not placeholder "red"
    assert_not_equal "red", manifest["theme_color"], "theme_color should not be placeholder 'red'"
    assert_not_equal "red", manifest["background_color"], "background_color should not be placeholder 'red'"

    # Colors should be valid hex format
    assert_match(/^#[0-9a-fA-F]{6}$/, manifest["theme_color"], "theme_color should be a valid hex color")
    assert_match(/^#[0-9a-fA-F]{6}$/, manifest["background_color"], "background_color should be a valid hex color")
  end

  test "manifest contains full app description" do
    get pwa_manifest_path(format: :json)
    manifest = JSON.parse(response.body)

    # Description should be more than a single word placeholder
    assert manifest["description"].length > 20, "description should be a full app description, not a placeholder"
  end

  test "manifest contains 512x512 icon with regular purpose" do
    get pwa_manifest_path(format: :json)
    manifest = JSON.parse(response.body)

    icons = manifest["icons"]
    assert icons.present?, "manifest should have icons"

    regular_icon = icons.find { |i| i["sizes"] == "512x512" && i["purpose"].nil? }
    assert regular_icon.present?, "manifest should have a 512x512 icon without maskable purpose"
  end

  test "manifest contains 512x512 icon with maskable purpose" do
    get pwa_manifest_path(format: :json)
    manifest = JSON.parse(response.body)

    icons = manifest["icons"]
    maskable_icon = icons.find { |i| i["sizes"] == "512x512" && i["purpose"] == "maskable" }
    assert maskable_icon.present?, "manifest should have a 512x512 maskable icon"
  end

  test "application layout contains manifest link tag" do
    get root_path
    assert_response :success

    # The layout should include a link to the manifest
    assert_select 'link[rel="manifest"]', true, "Layout should have manifest link tag"
  end

  test "application layout contains theme-color meta tag" do
    get root_path
    assert_response :success

    assert_select 'meta[name="theme-color"]', true, "Layout should have theme-color meta tag"
  end

  test "application layout contains apple-mobile-web-app-capable meta tag" do
    get root_path
    assert_response :success

    assert_select 'meta[name="apple-mobile-web-app-capable"]', true
  end

  test "application layout contains mobile-web-app-capable meta tag" do
    get root_path
    assert_response :success

    assert_select 'meta[name="mobile-web-app-capable"]', true
  end

  # Task 7.2: Service Worker Tests (Requirements: 2.4, 2.5, 2.7)

  test "service worker route serves JavaScript at /service-worker.js" do
    get pwa_service_worker_path(format: :js)
    assert_response :success
    assert_match(/javascript/, response.media_type)
  end

  test "service worker contains install event listener" do
    get pwa_service_worker_path(format: :js)
    assert_includes response.body, "install"
    assert_includes response.body, "addEventListener"
  end

  test "service worker pre-caches offline page during install" do
    get pwa_service_worker_path(format: :js)
    # The service worker should cache the offline page
    assert_includes response.body, "/offline.html"
    assert_includes response.body, "caches"
  end

  test "service worker contains fetch event listener" do
    get pwa_service_worker_path(format: :js)
    assert_includes response.body, "fetch"
  end

  test "service worker handles failed navigation requests with offline fallback" do
    get pwa_service_worker_path(format: :js)
    # Should check for navigation requests and serve offline page on failure
    assert_includes response.body, "navigate"
    assert_includes response.body, "offline"
  end

  test "offline page exists and is accessible" do
    get "/offline.html"
    assert_response :success
    assert_match(/offline/i, response.body)
  end

  test "offline page contains user-friendly message" do
    get "/offline.html"
    assert_response :success

    # Should have HTML structure with helpful message
    assert_includes response.body, "<!DOCTYPE html>"
    assert_includes response.body, "<html"
    # Should mention offline or no connection in some way
    assert_match(/offline|no.*(internet|connection|network)/i, response.body)
  end
end
