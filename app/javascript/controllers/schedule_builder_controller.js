import { Controller } from "@hotwired/stimulus"

/**
 * ScheduleBuilder Controller
 *
 * Manages dynamic addition and removal of schedule entry forms within
 * a medication's schedule section. Works with Turbo Stream responses
 * from MedicationSchedulesController for server-rendered form updates.
 *
 * Each schedule entry is rendered as a Turbo Frame, allowing individual
 * entries to be edited or removed without affecting the rest of the list.
 *
 * Usage:
 *   <div data-controller="schedule-builder"
 *        data-schedule-builder-medication-id-value="1">
 *     <div data-schedule-builder-target="list">
 *       <!-- Schedule entries rendered here as Turbo Frames -->
 *     </div>
 *     <p data-schedule-builder-target="empty">No schedules configured yet.</p>
 *   </div>
 *
 * Targets:
 *   - list:  Container where schedule entries are rendered
 *   - empty: Empty state message, hidden when entries exist
 *
 * Values:
 *   - medicationId: The medication ID for building request URLs
 *
 * Requirements: 4.5, 4.6
 */
export default class extends Controller {
  static targets = ["list", "empty"]
  static values = {
    medicationId: Number
  }

  connect() {
    this.updateEmptyState()
    this.observeListChanges()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  /**
   * Triggered when "Add Schedule" link is clicked.
   * Hides the empty state message since a form will appear.
   */
  add() {
    this.hideEmptyState()
  }

  /**
   * Triggered when a schedule entry is removed.
   * Updates the empty state visibility.
   */
  remove() {
    // Allow DOM to settle after Turbo Stream removal
    requestAnimationFrame(() => {
      this.updateEmptyState()
    })
  }

  /**
   * Observe child changes in the list target to auto-update empty state.
   * This catches Turbo Stream append/remove operations.
   */
  observeListChanges() {
    if (!this.hasListTarget) return

    this.observer = new MutationObserver(() => {
      this.updateEmptyState()
    })

    this.observer.observe(this.listTarget, {
      childList: true
    })
  }

  updateEmptyState() {
    if (!this.hasListTarget || !this.hasEmptyTarget) return

    const hasEntries = this.listTarget.children.length > 0
    this.emptyTarget.classList.toggle("hidden", hasEntries)
  }

  hideEmptyState() {
    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.add("hidden")
    }
  }
}
