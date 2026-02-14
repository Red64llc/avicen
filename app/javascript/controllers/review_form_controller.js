import { Controller } from "@hotwired/stimulus"

/**
 * Review Form Controller
 *
 * Handles the review form for document scanning with confidence indicators
 * and verification tracking. This controller:
 *
 * 1. Highlights fields with low confidence scores (below threshold)
 * 2. Tracks which fields have been user-verified through editing
 * 3. Updates hidden form fields to indicate verification state
 * 4. Supports adding and removing medications dynamically (Task 10.2)
 * 5. Supports adding and removing test results dynamically (Task 10.3)
 *
 * The confidence threshold is configurable via data attributes. Fields with
 * confidence below the threshold are highlighted with a warning border/ring
 * to draw user attention for review.
 *
 * When a user edits a field, it is marked as "verified" - the warning
 * highlight is removed and a hidden input is updated to indicate the
 * user has reviewed and accepted (or corrected) the value.
 *
 * Usage:
 *   <form data-controller="review-form"
 *         data-review-form-confidence-threshold-value="0.8">
 *
 *     <input data-review-form-target="field"
 *            data-field-name="drug_name"
 *            data-confidence="0.6"
 *            data-action="input->review-form#markVerified blur->review-form#markVerified" />
 *
 *     <input type="hidden"
 *            data-review-form-target="verifiedInput"
 *            data-field-name="drug_name" />
 *
 *     <span data-review-form-target="confidence"
 *           data-confidence="0.6">60% confidence</span>
 *
 *     <button data-review-form-target="submitButton">Submit</button>
 *
 *     <!-- For medications list -->
 *     <div data-review-form-target="medicationsList">
 *       <div data-review-form-target="medicationEntry">...</div>
 *     </div>
 *     <template data-review-form-target="medicationTemplate">...</template>
 *
 *     <!-- For test results list (biology reports) -->
 *     <div data-review-form-target="testResultsList">
 *       <div data-review-form-target="testResultEntry">...</div>
 *     </div>
 *     <template data-review-form-target="testResultTemplate">...</template>
 *   </form>
 *
 * Targets:
 *   - field:              Editable form fields with confidence data
 *   - confidence:         Confidence indicator elements (visual display)
 *   - submitButton:       Form submit button
 *   - verifiedInput:      Hidden inputs to track verification state
 *   - medicationsList:    Container for medication entries (for adding/removing)
 *   - medicationTemplate: Template element for new medication entries
 *   - medicationEntry:    Individual medication entry containers
 *   - testResultsList:    Container for test result entries (for adding/removing)
 *   - testResultTemplate: Template element for new test result entries
 *   - testResultEntry:    Individual test result entry containers
 *
 * Values:
 *   - confidenceThreshold: Minimum confidence level (0.0-1.0) before highlighting
 *                          Default: 0.8 (80%)
 *
 * Requirements: 5.1, 5.2, 5.3, 5.4, 5.7, 6.4
 */
export default class extends Controller {
  static targets = [
    "field",
    "confidence",
    "submitButton",
    "verifiedInput",
    "medicationsList",
    "medicationTemplate",
    "medicationEntry",
    "testResultsList",
    "testResultTemplate",
    "testResultEntry"
  ]

  static values = {
    confidenceThreshold: { type: Number, default: 0.8 }
  }

  /**
   * Initialize controller state and highlight low confidence fields
   */
  connect() {
    // Set of field names that have been user-verified
    this.verifiedFields = new Set()

    // Store original values to detect changes on blur
    this.storeOriginalValues()

    // Highlight low confidence fields on connect (Requirement 5.2)
    this.highlightLowConfidenceFields()
  }

  /**
   * Store original values for all field targets to detect changes
   */
  storeOriginalValues() {
    this.fieldTargets.forEach(field => {
      field.dataset.originalValue = field.value
    })
  }

  /**
   * Highlight fields with confidence below the threshold
   * Adds warning visual indicators to draw user attention
   *
   * Requirement 5.2: Visually highlight fields flagged as low-confidence
   * Requirement 6.4: Visual confidence indicators for each extracted field
   */
  highlightLowConfidenceFields() {
    this.fieldTargets.forEach(field => {
      const confidence = parseFloat(field.dataset.confidence)
      const fieldName = field.dataset.fieldName

      if (isNaN(confidence)) {
        return
      }

      if (confidence < this.confidenceThresholdValue) {
        this.addLowConfidenceHighlight(field)
      } else {
        this.removeLowConfidenceHighlight(field)
      }
    })
  }

  /**
   * Add low confidence visual highlight to a field
   * Uses amber/warning colors to indicate the field needs review
   *
   * @param {HTMLElement} field - The form field element
   */
  addLowConfidenceHighlight(field) {
    // Add warning ring for visibility
    field.classList.add("ring-2", "ring-amber-500", "border-amber-500")
    // Add slight background tint
    field.classList.add("bg-amber-50")
  }

  /**
   * Remove low confidence visual highlight from a field
   *
   * @param {HTMLElement} field - The form field element
   */
  removeLowConfidenceHighlight(field) {
    field.classList.remove("ring-2", "ring-amber-500", "border-amber-500")
    field.classList.remove("bg-amber-50")
  }

  /**
   * Mark a field as verified when user edits it
   * This is called on input and blur events
   *
   * Requirement 5.3: When user edits any extracted field, update the form value
   *
   * @param {Event} event - The input or blur event
   */
  markVerified(event) {
    const field = event.target
    const fieldName = field.dataset.fieldName

    if (!fieldName) {
      return
    }

    // For blur events, only mark verified if value actually changed
    if (event.type === "blur") {
      const originalValue = field.dataset.originalValue || ""
      if (field.value === originalValue) {
        return
      }
    }

    // Add to verified fields set
    this.verifiedFields.add(fieldName)

    // Update the hidden verified input
    this.updateVerifiedInput(fieldName, true)

    // Remove the low confidence highlight since user has reviewed
    this.removeLowConfidenceHighlight(field)

    // Update the original value for future blur comparisons
    field.dataset.originalValue = field.value
  }

  /**
   * Update the hidden input that tracks verification state for a field
   *
   * @param {string} fieldName - The name of the field
   * @param {boolean} verified - Whether the field is verified
   */
  updateVerifiedInput(fieldName, verified) {
    const verifiedInput = this.verifiedInputTargets.find(
      input => input.dataset.fieldName === fieldName
    )

    if (verifiedInput) {
      verifiedInput.value = verified ? "true" : ""
    }
  }

  /**
   * Check if a field has been verified by the user
   *
   * @param {string} fieldName - The name of the field to check
   * @returns {boolean} True if the field has been verified
   */
  isFieldVerified(fieldName) {
    return this.verifiedFields.has(fieldName)
  }

  /**
   * Get the confidence value for a field
   *
   * @param {string} fieldName - The name of the field
   * @returns {number|null} The confidence value or null if not found
   */
  getFieldConfidence(fieldName) {
    const field = this.fieldTargets.find(
      f => f.dataset.fieldName === fieldName
    )

    if (field && field.dataset.confidence) {
      return parseFloat(field.dataset.confidence)
    }

    return null
  }

  /**
   * Check if a field has low confidence (below threshold)
   *
   * @param {string} fieldName - The name of the field
   * @returns {boolean} True if confidence is below threshold
   */
  isLowConfidence(fieldName) {
    const confidence = this.getFieldConfidence(fieldName)
    return confidence !== null && confidence < this.confidenceThresholdValue
  }

  /**
   * Get all fields that are low confidence and not yet verified
   *
   * @returns {Array} Array of field names that need verification
   */
  getUnverifiedLowConfidenceFields() {
    const unverified = []

    this.fieldTargets.forEach(field => {
      const fieldName = field.dataset.fieldName
      const confidence = parseFloat(field.dataset.confidence)

      if (
        fieldName &&
        !isNaN(confidence) &&
        confidence < this.confidenceThresholdValue &&
        !this.verifiedFields.has(fieldName)
      ) {
        unverified.push(fieldName)
      }
    })

    return unverified
  }

  // --- Medication Add/Remove Methods (Task 10.2, Requirements 5.1, 5.4) ---

  /**
   * Add a new medication entry to the form
   * Uses the medication template to create a new entry with a unique index
   *
   * @param {Event} event - The click event from the "Add Medication" button
   */
  addMedication(event) {
    event.preventDefault()

    if (!this.hasMedicationTemplateTarget || !this.hasMedicationsListTarget) {
      console.warn("Review form: Missing medication template or list target")
      return
    }

    // Remove the empty medications message if present
    const emptyMessage = this.medicationsListTarget.querySelector(".empty-medications-message")
    if (emptyMessage) {
      emptyMessage.remove()
    }

    // Get the next index for the new medication
    const nextIndex = this.getNextMedicationIndex()

    // Clone the template content
    const template = this.medicationTemplateTarget
    const clone = template.content.cloneNode(true)

    // Replace NEW_INDEX placeholder with actual index in all relevant attributes
    this.replacePlaceholderIndex(clone, nextIndex)

    // Append the new medication entry to the list
    this.medicationsListTarget.appendChild(clone)

    // Re-initialize event handlers and store original values for new fields
    this.storeOriginalValues()

    // Focus the first input in the new medication entry
    const newEntry = this.medicationsListTarget.lastElementChild
    const firstInput = newEntry.querySelector("input[type='text']")
    if (firstInput) {
      firstInput.focus()
    }
  }

  /**
   * Remove a medication entry from the form
   *
   * @param {Event} event - The click event from the "Remove" button
   */
  removeMedication(event) {
    event.preventDefault()

    // Find the medication entry container
    const button = event.currentTarget
    const entry = button.closest("[data-review-form-target='medicationEntry']")

    if (!entry) {
      console.warn("Review form: Could not find medication entry to remove")
      return
    }

    // Remove the entry with a fade-out animation
    entry.style.transition = "opacity 0.2s ease-out"
    entry.style.opacity = "0"

    setTimeout(() => {
      entry.remove()

      // Show empty message if no medications remain
      if (this.medicationEntryTargets.length === 0 && this.hasMedicationsListTarget) {
        const emptyMessage = document.createElement("p")
        emptyMessage.className = "text-gray-500 text-sm empty-medications-message"
        emptyMessage.textContent = "No medications were extracted. You can add them manually using the button above."
        this.medicationsListTarget.appendChild(emptyMessage)
      }
    }, 200)
  }

  /**
   * Get the next available index for a new medication entry
   * Finds the highest existing index and returns the next number
   *
   * @returns {number} The next medication index
   */
  getNextMedicationIndex() {
    let maxIndex = -1

    this.medicationEntryTargets.forEach(entry => {
      const index = parseInt(entry.dataset.medicationIndex, 10)
      if (!isNaN(index) && index > maxIndex) {
        maxIndex = index
      }
    })

    return maxIndex + 1
  }

  /**
   * Replace the NEW_INDEX placeholder in a cloned template with the actual index
   *
   * @param {DocumentFragment} fragment - The cloned template content
   * @param {number} index - The actual index to use
   */
  replacePlaceholderIndex(fragment, index) {
    // Replace in element attributes
    const elements = fragment.querySelectorAll("*")
    elements.forEach(element => {
      // Update data-medication-index attribute
      if (element.dataset.medicationIndex === "NEW_INDEX") {
        element.dataset.medicationIndex = index.toString()
      }

      // Update name attributes (for form fields)
      if (element.name && element.name.includes("NEW_INDEX")) {
        element.name = element.name.replace(/NEW_INDEX/g, index.toString())
      }

      // Update id attributes
      if (element.id && element.id.includes("NEW_INDEX")) {
        element.id = element.id.replace(/NEW_INDEX/g, index.toString())
      }

      // Update for attributes on labels
      if (element.htmlFor && element.htmlFor.includes("NEW_INDEX")) {
        element.htmlFor = element.htmlFor.replace(/NEW_INDEX/g, index.toString())
      }

      // Update data-field-name attributes
      if (element.dataset.fieldName && element.dataset.fieldName.includes("NEW_INDEX")) {
        element.dataset.fieldName = element.dataset.fieldName.replace(/NEW_INDEX/g, index.toString())
      }

      // Update data-test-result-index attribute (for test results)
      if (element.dataset.testResultIndex === "NEW_INDEX") {
        element.dataset.testResultIndex = index.toString()
      }
    })
  }

  // --- Test Result Add/Remove Methods (Task 10.3, Requirements 5.1, 5.4) ---

  /**
   * Add a new test result entry to the form
   * Uses the test result template to create a new entry with a unique index
   *
   * @param {Event} event - The click event from the "Add Test Result" button
   */
  addTestResult(event) {
    event.preventDefault()

    if (!this.hasTestResultTemplateTarget || !this.hasTestResultsListTarget) {
      console.warn("Review form: Missing test result template or list target")
      return
    }

    // Remove the empty test results message if present
    const emptyMessage = this.testResultsListTarget.querySelector(".empty-test-results-message")
    if (emptyMessage) {
      emptyMessage.remove()
    }

    // Get the next index for the new test result
    const nextIndex = this.getNextTestResultIndex()

    // Clone the template content
    const template = this.testResultTemplateTarget
    const clone = template.content.cloneNode(true)

    // Replace NEW_INDEX placeholder with actual index in all relevant attributes
    this.replacePlaceholderIndex(clone, nextIndex)

    // Append the new test result entry to the list
    this.testResultsListTarget.appendChild(clone)

    // Re-initialize event handlers and store original values for new fields
    this.storeOriginalValues()

    // Focus the first input in the new test result entry
    const newEntry = this.testResultsListTarget.lastElementChild
    const firstInput = newEntry.querySelector("input[type='text']")
    if (firstInput) {
      firstInput.focus()
    }
  }

  /**
   * Remove a test result entry from the form
   *
   * @param {Event} event - The click event from the "Remove" button
   */
  removeTestResult(event) {
    event.preventDefault()

    // Find the test result entry container
    const button = event.currentTarget
    const entry = button.closest("[data-review-form-target='testResultEntry']")

    if (!entry) {
      console.warn("Review form: Could not find test result entry to remove")
      return
    }

    // Remove the entry with a fade-out animation
    entry.style.transition = "opacity 0.2s ease-out"
    entry.style.opacity = "0"

    setTimeout(() => {
      entry.remove()

      // Show empty message if no test results remain
      if (this.testResultEntryTargets.length === 0 && this.hasTestResultsListTarget) {
        const emptyMessage = document.createElement("p")
        emptyMessage.className = "text-gray-500 text-sm empty-test-results-message"
        emptyMessage.textContent = "No test results were extracted. You can add them manually using the button above."
        this.testResultsListTarget.appendChild(emptyMessage)
      }
    }, 200)
  }

  /**
   * Get the next available index for a new test result entry
   * Finds the highest existing index and returns the next number
   *
   * @returns {number} The next test result index
   */
  getNextTestResultIndex() {
    let maxIndex = -1

    this.testResultEntryTargets.forEach(entry => {
      const index = parseInt(entry.dataset.testResultIndex, 10)
      if (!isNaN(index) && index > maxIndex) {
        maxIndex = index
      }
    })

    return maxIndex + 1
  }
}
