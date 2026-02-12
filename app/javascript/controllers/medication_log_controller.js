import { Controller } from "@hotwired/stimulus"

/**
 * MedicationLog Controller
 *
 * Manages button state during Turbo Stream requests for medication logging
 * quick-actions (taken, skipped, undo). Disables buttons while a request
 * is in progress to prevent duplicate submissions.
 *
 * Usage:
 *   <div data-controller="medication-log">
 *     <form data-action="submit->medication-log#submit">
 *       <button data-medication-log-target="submitButton">Taken</button>
 *     </form>
 *   </div>
 *
 * Targets:
 *   - submitButton: Buttons to disable during request processing
 *   - reasonField:  Optional text input for skip reason
 *
 * Requirements: 7.3, 7.4, 7.6
 */
export default class extends Controller {
  static targets = ["submitButton", "reasonField"]

  /**
   * Called when a form is submitted. Disables all submit buttons
   * within this controller's scope to prevent duplicate submissions.
   * Buttons are re-enabled when Turbo replaces the element (via Stream).
   */
  submit() {
    this.submitButtonTargets.forEach(button => {
      button.disabled = true
    })
  }
}
