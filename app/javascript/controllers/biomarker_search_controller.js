import { Autocomplete } from "stimulus-autocomplete"

// Wraps stimulus-autocomplete with the biomarker search endpoint URL.
//
// Extends the Autocomplete controller with a default URL pointing to the
// /biomarkers/search endpoint. The parent class handles all autocomplete behavior:
// debounced input, fetching results, dropdown rendering, and hidden input
// value capture.
//
// Additionally, this controller handles the autocomplete selection event to
// auto-fill the unit, ref_min, and ref_max fields from the selected biomarker's
// data attributes.
//
// Stimulus automatically merges static values from parent and child classes
// through the prototype chain, so only overridden defaults need to be declared.
//
// Usage:
//   <div data-controller="biomarker-search"
//        data-biomarker-search-url-value="/biomarkers/search"
//        data-biomarker-search-min-length-value="2"
//        role="combobox">
//     <input type="text"
//            data-biomarker-search-target="input"
//            placeholder="Search for a biomarker..." />
//     <input type="hidden"
//            name="test_result[biomarker_id]"
//            data-biomarker-search-target="hidden" />
//     <ul data-biomarker-search-target="results"></ul>
//
//     <!-- Auto-fill targets (optional) -->
//     <input type="text"
//            name="test_result[unit]"
//            data-biomarker-search-target="unitField" />
//     <input type="number"
//            name="test_result[ref_min]"
//            data-biomarker-search-target="refMinField" />
//     <input type="number"
//            name="test_result[ref_max]"
//            data-biomarker-search-target="refMaxField" />
//   </div>
//
// Targets (inherited from Autocomplete):
//   - input:   The visible text field the user types into
//   - hidden:  Stores the selected Biomarker ID for form submission
//   - results: Container where server-fetched <li> items are rendered
//
// Additional Targets (for auto-fill):
//   - unitField:   Input field for unit of measurement
//   - refMinField: Input field for reference range minimum
//   - refMaxField: Input field for reference range maximum
//
// Values:
//   - url:        URL for search endpoint (default: "/biomarkers/search")
//   - minLength:  Minimum characters before search triggers (default: 2)
//   - delay:      Debounce delay in ms (default: 300)
//   - queryParam: URL parameter name for search term (default: "q")
//
// Requirements: 1.2, 1.3
export default class extends Autocomplete {
  static targets = [ "unitField", "refMinField", "refMaxField" ]

  static values = {
    url: { type: String, default: "/biomarkers/search" },
    minLength: { type: Number, default: 2 }
  }

  connect() {
    super.connect()

    // Listen for autocomplete selection event from stimulus-autocomplete
    this.element.addEventListener("autocomplete.change", this.autofillFields.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("autocomplete.change", this.autofillFields.bind(this))
    super.disconnect()
  }

  // Handle autocomplete selection to auto-fill form fields
  autofillFields(event) {
    const selectedOption = event.detail.selected

    if (!selectedOption) {
      this.clearAutofilledFields()
      return
    }

    // Extract biomarker data from selected option's data attributes
    const unit = selectedOption.dataset.biomarkerUnit
    const refMin = selectedOption.dataset.biomarkerRefMin
    const refMax = selectedOption.dataset.biomarkerRefMax

    // Auto-fill fields if targets exist
    if (this.hasUnitFieldTarget && unit) {
      this.unitFieldTarget.value = unit
    }

    if (this.hasRefMinFieldTarget && refMin) {
      this.refMinFieldTarget.value = refMin
    }

    if (this.hasRefMaxFieldTarget && refMax) {
      this.refMaxFieldTarget.value = refMax
    }
  }

  clearAutofilledFields() {
    if (this.hasUnitFieldTarget) {
      this.unitFieldTarget.value = ""
    }

    if (this.hasRefMinFieldTarget) {
      this.refMinFieldTarget.value = ""
    }

    if (this.hasRefMaxFieldTarget) {
      this.refMaxFieldTarget.value = ""
    }
  }
}
