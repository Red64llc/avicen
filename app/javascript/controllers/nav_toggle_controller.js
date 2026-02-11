import { Controller } from "@hotwired/stimulus"

/**
 * NavToggle Controller
 *
 * Controls the mobile navigation menu visibility.
 * Toggles the hamburger menu open/closed state.
 *
 * Usage:
 *   <nav data-controller="nav-toggle">
 *     <button data-action="click->nav-toggle#toggle" data-nav-toggle-target="button">
 *       <svg data-nav-toggle-target="openIcon">...</svg>
 *       <svg data-nav-toggle-target="closeIcon" class="hidden">...</svg>
 *     </button>
 *     <div data-nav-toggle-target="menu" class="hidden">
 *       <!-- Mobile menu content -->
 *     </div>
 *   </nav>
 */
export default class extends Controller {
  static targets = ["menu", "button", "openIcon", "closeIcon"]

  connect() {
    this.isOpen = false
  }

  toggle() {
    this.isOpen = !this.isOpen
    this.updateVisibility()
  }

  open() {
    this.isOpen = true
    this.updateVisibility()
  }

  close() {
    this.isOpen = false
    this.updateVisibility()
  }

  updateVisibility() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.toggle("hidden", !this.isOpen)
    }

    if (this.hasOpenIconTarget) {
      this.openIconTarget.classList.toggle("hidden", this.isOpen)
    }

    if (this.hasCloseIconTarget) {
      this.closeIconTarget.classList.toggle("hidden", !this.isOpen)
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", this.isOpen.toString())
    }
  }
}
