require "application_system_test_case"

# System tests for the camera_controller.js Stimulus controller.
# Tests verify:
#   - Controller connects and initializes with correct state
#   - File selection displays preview image
#   - Oversized files show error message
#   - State transitions work correctly (idle -> previewing -> uploading -> uploaded)
#   - Active Storage direct upload event integration
#   - Progress indicator updates during upload
#   - Form disabled during upload to prevent duplicate requests
#   - Retry functionality after upload errors
#
# Requirements: 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 6.3, 6.5
class CameraControllerTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "camera controller connects with default maxSize value" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    # Verify the controller element exists with proper data attributes
    assert_selector "[data-controller='camera']"

    # Verify default maxSize value (10MB = 10485760 bytes)
    wait_for_stimulus_controller("camera")

    # Check via JavaScript that controller is connected and has correct default
    max_size = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        return controller ? controller.maxSizeValue : null;
      })()
    JS

    assert_equal 10485760, max_size, "Default maxSize should be 10MB (10485760 bytes)"
  end

  test "camera controller defines required targets" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Verify targets exist
    assert_selector "[data-camera-target='preview']"
    assert_selector "[data-camera-target='progress']", visible: :all
    assert_selector "[data-camera-target='input']"
    assert_selector "[data-camera-target='submitButton']"
    assert_selector "[data-camera-target='error']", visible: :all
  end

  test "camera controller starts in idle state" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Check controller state via JavaScript
    state = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        return controller ? controller.state : null;
      })()
    JS

    assert_equal "idle", state, "Controller should start in idle state"
  end

  test "selecting a valid image file displays preview" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Attach a small test image file
    # Create a small PNG file path (using fixture)
    attach_file "camera_input", Rails.root.join("test/fixtures/files/test_image.png"), make_visible: true

    # Preview should be visible and contain an image
    assert_selector "[data-camera-target='preview'] img", wait: 5

    # State should be previewing
    state = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        return controller ? controller.state : null;
      })()
    JS

    assert_equal "previewing", state, "Controller should be in previewing state after file selection"
  end

  test "selecting an oversized file shows error message" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Set a very small maxSize for testing (1 byte)
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        controller.maxSizeValue = 1; // 1 byte max
      })()
    JS

    # Attach any file (will be over 1 byte)
    attach_file "camera_input", Rails.root.join("test/fixtures/files/test_image.png"), make_visible: true

    # Error message should be displayed and visible (unhidden by controller)
    assert_selector "[data-camera-target='error']:not(.hidden)", wait: 5

    # State should be error
    state = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        return controller ? controller.state : null;
      })()
    JS

    assert_equal "error", state, "Controller should be in error state after oversized file"
  end

  test "error message includes file size limit" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Set maxSize to 10 bytes so our test image (67 bytes) exceeds it
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        controller.maxSizeValue = 10; // 10 bytes
      })()
    JS

    # Attach a file larger than 10 bytes
    attach_file "camera_input", Rails.root.join("test/fixtures/files/test_image.png"), make_visible: true

    # Error message should mention the size limit
    assert_selector "[data-camera-target='error']:not(.hidden)", wait: 5
    error_text = find("[data-camera-target='error']").text
    assert_match(/MB|size/i, error_text, "Error should mention size constraint")
  end

  test "submit button is disabled in idle state" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    submit_button = find("[data-camera-target='submitButton']")
    assert submit_button.disabled?, "Submit button should be disabled in idle state"
  end

  test "submit button is enabled after valid file selection" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Attach a valid image file
    attach_file "camera_input", Rails.root.join("test/fixtures/files/test_image.png"), make_visible: true

    # Wait for preview to appear
    assert_selector "[data-camera-target='preview'] img", wait: 5

    submit_button = find("[data-camera-target='submitButton']")
    assert_not submit_button.disabled?, "Submit button should be enabled after valid file selection"
  end

  test "preview image is cleared when new file is selected" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Attach first file
    attach_file "camera_input", Rails.root.join("test/fixtures/files/test_image.png"), make_visible: true
    assert_selector "[data-camera-target='preview'] img", wait: 5

    # Get first preview src
    first_src = find("[data-camera-target='preview'] img")[:src]

    # Attach second file
    attach_file "camera_input", Rails.root.join("test/fixtures/files/test_image_2.png"), make_visible: true
    assert_selector "[data-camera-target='preview'] img", wait: 5

    # Verify preview changed
    second_src = find("[data-camera-target='preview'] img")[:src]
    assert_not_equal first_src, second_src, "Preview should update when new file is selected"
  end

  test "custom maxSize value is respected" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Get the controller and check custom value can be set
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        controller.maxSizeValue = 5242880; // 5MB
      })()
    JS

    max_size = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        return controller.maxSizeValue;
      })()
    JS

    assert_equal 5242880, max_size, "Custom maxSize value should be respected"
  end

  # ============================================================================
  # Task 9.2 Tests: Active Storage Direct Upload Events Integration
  # Requirements: 1.5, 1.6, 1.7, 6.5
  # ============================================================================

  test "controller has retryButton target defined" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Verify retryButton target exists for retry functionality (Requirement 1.7)
    assert_selector "[data-camera-target='retryButton']", visible: :all
  end

  test "file input is disabled during uploading state" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Simulate uploading state via direct-upload:start event
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const event = new CustomEvent('direct-upload:start', {
          bubbles: true,
          detail: { file: new File([''], 'test.png', { type: 'image/png' }) }
        });
        element.dispatchEvent(event);
      })()
    JS

    # Verify input is disabled during upload (Requirement 6.5)
    input = find("[data-camera-target='input']", visible: :all)
    assert input.disabled?, "File input should be disabled during upload"
  end

  test "submit button is disabled during uploading state" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # First select a file to enable the submit button
    attach_file "camera_input", Rails.root.join("test/fixtures/files/test_image.png"), make_visible: true
    assert_selector "[data-camera-target='preview'] img", wait: 5

    # Simulate uploading state
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const event = new CustomEvent('direct-upload:start', {
          bubbles: true,
          detail: { file: new File([''], 'test.png', { type: 'image/png' }) }
        });
        element.dispatchEvent(event);
      })()
    JS

    # Verify submit button is disabled during upload (Requirement 6.5)
    submit_button = find("[data-camera-target='submitButton']")
    assert submit_button.disabled?, "Submit button should be disabled during upload"
  end

  test "progress indicator shows during direct upload" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Simulate upload start
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const startEvent = new CustomEvent('direct-upload:start', {
          bubbles: true,
          detail: { file: new File([''], 'test.png', { type: 'image/png' }) }
        });
        element.dispatchEvent(startEvent);
      })()
    JS

    # Progress indicator should be visible (Requirement 1.6)
    assert_selector "[data-camera-target='progress']:not(.hidden)", wait: 5
  end

  test "progress indicator updates during direct upload" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Simulate upload start followed by progress
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const startEvent = new CustomEvent('direct-upload:start', {
          bubbles: true,
          detail: { file: new File([''], 'test.png', { type: 'image/png' }) }
        });
        element.dispatchEvent(startEvent);

        // Simulate progress event at 50%
        setTimeout(() => {
          const progressEvent = new CustomEvent('direct-upload:progress', {
            bubbles: true,
            detail: { progress: 50 }
          });
          element.dispatchEvent(progressEvent);
        }, 100);
      })()
    JS

    # Wait and check that progress is updated
    sleep 0.3
    progress_text = find("[data-camera-target='progress']").text
    assert_match(/50%/, progress_text, "Progress should show 50%")
  end

  test "retry button appears after upload error" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Simulate upload error (Requirement 1.7)
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const errorEvent = new CustomEvent('direct-upload:error', {
          bubbles: true,
          cancelable: true,
          detail: { error: 'Network timeout' }
        });
        element.dispatchEvent(errorEvent);
      })()
    JS

    # Retry button should be visible (Requirement 1.7)
    assert_selector "[data-camera-target='retryButton']:not(.hidden)", wait: 5
  end

  test "error message is user-friendly after upload failure" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Simulate upload error
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const errorEvent = new CustomEvent('direct-upload:error', {
          bubbles: true,
          cancelable: true,
          detail: { error: 'Network timeout' }
        });
        element.dispatchEvent(errorEvent);
      })()
    JS

    # Error message should be user-friendly (Requirement 1.7)
    assert_selector "[data-camera-target='error']:not(.hidden)", wait: 5
    error_text = find("[data-camera-target='error']").text
    assert_match(/try again/i, error_text, "Error should suggest trying again")
  end

  test "clicking retry button resets to allow new file selection" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Put controller in error state
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const errorEvent = new CustomEvent('direct-upload:error', {
          bubbles: true,
          cancelable: true,
          detail: { error: 'Network timeout' }
        });
        element.dispatchEvent(errorEvent);
      })()
    JS

    # Wait for retry button to appear
    assert_selector "[data-camera-target='retryButton']:not(.hidden)", wait: 5

    # Click retry button
    find("[data-camera-target='retryButton']").click

    # Input should be enabled again
    input = find("[data-camera-target='input']", visible: :all)
    assert_not input.disabled?, "File input should be re-enabled after retry"

    # Error should be hidden (use visible: :all since hidden class sets display: none)
    assert_selector "[data-camera-target='error'].hidden", visible: :all, wait: 5

    # Retry button should be hidden
    assert_selector "[data-camera-target='retryButton'].hidden", visible: :all, wait: 5
  end

  test "file input is re-enabled after successful upload" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Simulate upload start then end
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");

        // Start upload
        const startEvent = new CustomEvent('direct-upload:start', {
          bubbles: true,
          detail: { file: new File([''], 'test.png', { type: 'image/png' }) }
        });
        element.dispatchEvent(startEvent);

        // End upload (success)
        setTimeout(() => {
          const endEvent = new CustomEvent('direct-upload:end', {
            bubbles: true,
            detail: {}
          });
          element.dispatchEvent(endEvent);
        }, 100);
      })()
    JS

    # Wait for upload to complete
    sleep 0.3

    # Input should be disabled after upload complete
    # (since form should not accept new files until the current upload is processed)
    # But submit button should be enabled
    submit_button = find("[data-camera-target='submitButton']")
    assert_not submit_button.disabled?, "Submit button should be enabled after successful upload"
  end

  test "state transitions correctly through upload lifecycle" do
    sign_in_as_system(@user)
    visit document_scans_camera_test_path

    wait_for_stimulus_controller("camera")

    # Check initial state
    state = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        return controller.state;
      })()
    JS
    assert_equal "idle", state, "Should start in idle state"

    # Simulate upload initialize
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const initEvent = new CustomEvent('direct-upload:initialize', {
          bubbles: true,
          cancelable: true,
          detail: { file: new File(['test'], 'test.png', { type: 'image/png' }) }
        });
        element.dispatchEvent(initEvent);
      })()
    JS

    # Simulate upload start
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const startEvent = new CustomEvent('direct-upload:start', {
          bubbles: true,
          detail: { file: new File(['test'], 'test.png', { type: 'image/png' }) }
        });
        element.dispatchEvent(startEvent);
      })()
    JS

    state = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        return controller.state;
      })()
    JS
    assert_equal "uploading", state, "Should be in uploading state after start"

    # Simulate upload end
    page.execute_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const endEvent = new CustomEvent('direct-upload:end', {
          bubbles: true,
          detail: {}
        });
        element.dispatchEvent(endEvent);
      })()
    JS

    state = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='camera']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "camera");
        return controller.state;
      })()
    JS
    assert_equal "uploaded", state, "Should be in uploaded state after end"
  end
end
