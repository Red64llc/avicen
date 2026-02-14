import { Controller } from "@hotwired/stimulus"

/**
 * Camera Controller
 *
 * Handles camera capture, file selection, and upload progress for document scanning.
 * Implements a state machine for managing the upload lifecycle.
 * Integrates with Active Storage direct upload events for progress tracking and error handling.
 *
 * States:
 *   - idle:       Initial state, waiting for file selection
 *   - previewing: File selected, preview displayed
 *   - uploading:  Active Storage direct upload in progress
 *   - uploaded:   Upload complete, ready for processing
 *   - error:      Validation or upload error occurred
 *
 * Usage:
 *   <div data-controller="camera"
 *        data-camera-max-size-value="10485760">
 *     <div data-camera-target="preview">
 *       <!-- Preview image appears here -->
 *     </div>
 *     <div data-camera-target="progress" class="hidden">
 *       <!-- Upload progress bar -->
 *     </div>
 *     <div data-camera-target="error" class="hidden">
 *       <!-- Error messages -->
 *     </div>
 *     <input type="file"
 *            data-camera-target="input"
 *            data-action="change->camera#handleFileSelect" />
 *     <button data-camera-target="submitButton" disabled>Continue</button>
 *     <button data-camera-target="retryButton"
 *             data-action="click->camera#retry"
 *             class="hidden">Try again</button>
 *   </div>
 *
 * Targets:
 *   - preview:      Container for image preview
 *   - progress:     Upload progress indicator
 *   - error:        Error message display area
 *   - input:        File input element(s) - supports multiple inputs (camera capture + file upload)
 *   - submitButton: Submit/continue button
 *   - retryButton:  Retry button shown after upload errors (Requirement 1.7)
 *
 * Values:
 *   - maxSize: Maximum file size in bytes (default: 10MB = 10485760)
 *
 * Requirements: 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 6.3, 6.5
 */
export default class extends Controller {
  static targets = ["preview", "progress", "input", "submitButton", "error", "retryButton"]

  static values = {
    maxSize: { type: Number, default: 10485760 } // 10MB
  }

  /**
   * Initialize controller state on connect
   */
  connect() {
    this.state = "idle"
    this.updateUI()
    this.setupDirectUploadListeners()
  }

  /**
   * Clean up event listeners on disconnect
   */
  disconnect() {
    this.removeDirectUploadListeners()
  }

  /**
   * Handle file selection from input element
   * Validates file size and displays preview if valid
   *
   * @param {Event} event - Change event from file input
   */
  handleFileSelect(event) {
    const file = event.target.files[0]

    if (!file) {
      this.resetToIdle()
      return
    }

    // Validate file size (Requirement 1.8, 1.9)
    if (!this.validateFileSize(file)) {
      return
    }

    // Clear any previous errors
    this.clearError()

    // Display preview (Requirement 1.4)
    this.displayPreview(file)
  }

  /**
   * Validate that file does not exceed maximum size
   *
   * @param {File} file - File to validate
   * @returns {boolean} True if valid, false if oversized
   */
  validateFileSize(file) {
    if (file.size > this.maxSizeValue) {
      this.showError(this.formatSizeError(file.size))
      this.state = "error"
      this.updateUI()
      return false
    }
    return true
  }

  /**
   * Format human-readable error message for oversized files
   *
   * @param {number} actualSize - Actual file size in bytes
   * @returns {string} Formatted error message
   */
  formatSizeError(actualSize) {
    const maxMB = (this.maxSizeValue / (1024 * 1024)).toFixed(1)
    const actualMB = (actualSize / (1024 * 1024)).toFixed(1)
    return `File size (${actualMB} MB) exceeds the maximum allowed size of ${maxMB} MB. Please select a smaller file.`
  }

  /**
   * Display image preview for selected file
   *
   * @param {File} file - Selected image file
   */
  displayPreview(file) {
    // Check if file is an image type
    if (file.type.startsWith("image/")) {
      const reader = new FileReader()
      reader.onload = (e) => {
        this.renderImagePreview(e.target.result)
        this.state = "previewing"
        this.updateUI()
      }
      reader.onerror = () => {
        this.showError("Failed to read file. Please try again.")
        this.state = "error"
        this.updateUI()
      }
      reader.readAsDataURL(file)
    } else if (file.type === "application/pdf") {
      // For PDFs, show a placeholder preview
      this.renderPdfPreview(file.name)
      this.state = "previewing"
      this.updateUI()
    } else {
      // Unsupported file type
      this.showError("Unsupported file type. Please select a JPEG, PNG, HEIC, or PDF file.")
      this.state = "error"
      this.updateUI()
    }
  }

  /**
   * Render image preview in the preview target
   *
   * @param {string} dataUrl - Base64 data URL of the image
   */
  renderImagePreview(dataUrl) {
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = `
        <img src="${dataUrl}"
             alt="Document preview"
             class="max-w-full max-h-64 mx-auto rounded-lg shadow" />
      `
      this.previewTarget.classList.remove("hidden")
    }
  }

  /**
   * Render PDF placeholder preview
   *
   * @param {string} filename - Name of the PDF file
   */
  renderPdfPreview(filename) {
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = `
        <div class="flex flex-col items-center justify-center p-4">
          <svg class="w-16 h-16 text-red-500 mb-2" fill="currentColor" viewBox="0 0 24 24">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6zm-1 1v5h5l-5-5zM6 20V4h6v6h6v10H6z"/>
            <path d="M9 13h6v1H9v-1zm0 2h6v1H9v-1zm0 2h4v1H9v-1z"/>
          </svg>
          <span class="text-sm text-gray-600 font-medium">${this.escapeHtml(filename)}</span>
          <span class="text-xs text-gray-400">PDF document</span>
        </div>
      `
      this.previewTarget.classList.remove("hidden")
    }
  }

  /**
   * Escape HTML to prevent XSS
   *
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  /**
   * Show error message to user
   *
   * @param {string} message - Error message to display
   */
  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    }
  }

  /**
   * Clear error message
   */
  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ""
      this.errorTarget.classList.add("hidden")
    }
  }

  /**
   * Reset controller to idle state
   */
  resetToIdle() {
    this.state = "idle"
    this.clearError()
    this.clearPreview()
    this.clearFileInput()
    this.updateUI()
  }

  /**
   * Handle retry action after upload error
   * Resets the controller state to allow new file selection
   *
   * Requirement 1.7: Allow retry option after upload failure
   *
   * @param {Event} event - Click event from retry button
   */
  retry(event) {
    if (event) {
      event.preventDefault()
    }
    this.resetToIdle()
  }

  /**
   * Clear the file input value to allow re-selection of the same file
   * Handles multiple input targets (camera capture and file upload)
   */
  clearFileInput() {
    // Clear all input targets (supports multiple file inputs)
    this.inputTargets.forEach(input => {
      input.value = ""
    })
  }

  /**
   * Clear the preview area
   */
  clearPreview() {
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = `
        <span class="text-gray-400">Image preview will appear here</span>
      `
      this.previewTarget.classList.add("hidden")
    }
  }

  /**
   * Update UI based on current state
   * Controls visibility of targets, button enabled state, and form interactivity
   *
   * Requirement 6.5: Disable form during upload to prevent duplicate requests
   */
  updateUI() {
    const isUploading = this.state === "uploading"
    const isError = this.state === "error"
    const canSubmit = this.state === "previewing" || this.state === "uploaded"

    // Update submit button state
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !canSubmit
    }

    // Update file input state (Requirement 6.5)
    // Disable all inputs during upload to prevent duplicate requests
    this.inputTargets.forEach(input => {
      input.disabled = isUploading
    })

    // Update progress visibility (Requirement 1.6)
    if (this.hasProgressTarget) {
      this.progressTarget.classList.toggle("hidden", !isUploading)
    }

    // Update retry button visibility (Requirement 1.7)
    if (this.hasRetryButtonTarget) {
      this.retryButtonTarget.classList.toggle("hidden", !isError)
    }

    // Update error visibility is handled by showError/clearError
  }

  /**
   * Setup listeners for Active Storage direct upload events
   * These events fire during direct upload to track progress
   */
  setupDirectUploadListeners() {
    this.handleUploadInitialize = this.handleUploadInitialize.bind(this)
    this.handleUploadStart = this.handleUploadStart.bind(this)
    this.handleUploadProgress = this.handleUploadProgress.bind(this)
    this.handleUploadError = this.handleUploadError.bind(this)
    this.handleUploadEnd = this.handleUploadEnd.bind(this)

    this.element.addEventListener("direct-upload:initialize", this.handleUploadInitialize)
    this.element.addEventListener("direct-upload:start", this.handleUploadStart)
    this.element.addEventListener("direct-upload:progress", this.handleUploadProgress)
    this.element.addEventListener("direct-upload:error", this.handleUploadError)
    this.element.addEventListener("direct-upload:end", this.handleUploadEnd)
  }

  /**
   * Remove direct upload event listeners
   */
  removeDirectUploadListeners() {
    this.element.removeEventListener("direct-upload:initialize", this.handleUploadInitialize)
    this.element.removeEventListener("direct-upload:start", this.handleUploadStart)
    this.element.removeEventListener("direct-upload:progress", this.handleUploadProgress)
    this.element.removeEventListener("direct-upload:error", this.handleUploadError)
    this.element.removeEventListener("direct-upload:end", this.handleUploadEnd)
  }

  /**
   * Handle direct upload initialization
   * Fires when upload is about to begin
   *
   * @param {CustomEvent} event - Direct upload event
   */
  handleUploadInitialize(event) {
    // Validate file size one more time before upload starts
    const { file } = event.detail
    if (file && file.size > this.maxSizeValue) {
      event.preventDefault()
      this.showError(this.formatSizeError(file.size))
      this.state = "error"
      this.updateUI()
    }
  }

  /**
   * Handle direct upload start
   * Fires when upload actually begins
   *
   * Requirement 1.5: Direct upload to Active Storage
   * Requirement 1.6: Display upload progress indicator
   * Requirement 6.5: Disable form during upload to prevent duplicate requests
   *
   * @param {CustomEvent} event - Direct upload event
   */
  handleUploadStart(event) {
    this.state = "uploading"
    this.clearError()
    this.updateUI()
    this.updateProgress(0)
  }

  /**
   * Handle direct upload progress
   * Fires periodically during upload with progress percentage
   *
   * @param {CustomEvent} event - Direct upload event with progress
   */
  handleUploadProgress(event) {
    const { progress } = event.detail
    this.updateProgress(progress)
  }

  /**
   * Handle direct upload error
   * Fires when upload fails
   *
   * Requirement 1.7: Handle upload errors with user-friendly messages and retry option
   *
   * @param {CustomEvent} event - Direct upload event with error
   */
  handleUploadError(event) {
    event.preventDefault()
    const { error } = event.detail
    const userFriendlyError = this.formatUploadError(error)
    this.showError(userFriendlyError)
    this.state = "error"
    this.updateUI()
  }

  /**
   * Format upload error into user-friendly message
   *
   * @param {string} error - Raw error message from Active Storage
   * @returns {string} User-friendly error message
   */
  formatUploadError(error) {
    // Map common error patterns to user-friendly messages
    const errorMessage = String(error || "").toLowerCase()

    if (errorMessage.includes("network") || errorMessage.includes("timeout")) {
      return "Upload failed due to a network issue. Please check your connection and try again."
    }

    if (errorMessage.includes("size") || errorMessage.includes("too large")) {
      return "The file is too large to upload. Please select a smaller file and try again."
    }

    if (errorMessage.includes("type") || errorMessage.includes("format")) {
      return "The file format is not supported. Please select a JPEG, PNG, HEIC, or PDF file and try again."
    }

    // Default message
    return `Upload failed: ${error}. Please try again.`
  }

  /**
   * Handle direct upload end
   * Fires when upload completes successfully
   *
   * @param {CustomEvent} event - Direct upload event
   */
  handleUploadEnd(event) {
    this.state = "uploaded"
    this.updateProgress(100)
    this.updateUI()
  }

  /**
   * Update progress bar display
   *
   * Requirement 1.6: Display upload progress indicator
   *
   * @param {number} percent - Progress percentage (0-100)
   */
  updateProgress(percent) {
    if (this.hasProgressTarget) {
      // Find progress bar element - support various class patterns
      const progressBar = this.progressTarget.querySelector("[data-camera-target='progressBar']") ||
                          this.progressTarget.querySelector("[class*='bg-blue-600']") ||
                          this.progressTarget.querySelector("[class*='bg-primary']") ||
                          this.progressTarget.querySelector(".progress-bar")
      if (progressBar) {
        progressBar.style.width = `${percent}%`
      }

      // Find and update label
      const label = this.progressTarget.querySelector("span") ||
                    this.progressTarget.querySelector("p")
      if (label) {
        if (percent >= 100) {
          label.textContent = "Upload complete!"
        } else {
          label.textContent = `Uploading... ${Math.round(percent)}%`
        }
      }
    }
  }
}
