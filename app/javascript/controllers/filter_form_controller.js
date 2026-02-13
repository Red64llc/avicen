import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter-form"
export default class extends Controller {
  static values = {
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  // Handle input changes with debouncing
  filterInput(event) {
    // Clear existing timeout
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // Set new timeout to submit form after debounce period
    this.timeout = setTimeout(() => {
      this.submitForm()
    }, this.debounceValue)
  }

  // Handle immediate changes (like date pickers)
  filterChange(event) {
    // Clear any pending timeout
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // Submit immediately for select/date inputs
    this.submitForm()
  }

  submitForm() {
    // Request submit triggers form submission via Turbo Frame
    this.element.requestSubmit()
  }
}
