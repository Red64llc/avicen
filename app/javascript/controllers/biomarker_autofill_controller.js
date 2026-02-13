import { Controller } from "@hotwired/stimulus"

// Auto-fills unit and reference range fields when a biomarker is selected.
//
// This controller listens for changes to a biomarker select dropdown and
// automatically populates the unit, ref_min, and ref_max fields with the
// biomarker's default values from the data attributes.
//
// Usage:
//   <div data-controller="biomarker-autofill">
//     <select data-biomarker-autofill-target="biomarkerSelect"
//             data-action="change->biomarker-autofill#autofill">
//       <option value="">Select a biomarker</option>
//       <option value="1"
//               data-unit="mg/dL"
//               data-ref-min="70.0"
//               data-ref-max="100.0">Glucose</option>
//     </select>
//     <input data-biomarker-autofill-target="unitField" />
//     <input data-biomarker-autofill-target="refMinField" />
//     <input data-biomarker-autofill-target="refMaxField" />
//   </div>
//
// Targets:
//   - biomarkerSelect: The select dropdown for biomarker selection
//   - unitField:       The input field for unit of measurement
//   - refMinField:     The input field for minimum reference value
//   - refMaxField:     The input field for maximum reference value
//
// Requirements: 1.3, 1.4, 5.2
export default class extends Controller {
  static targets = [ "biomarkerSelect", "unitField", "refMinField", "refMaxField" ]

  connect() {
    // If biomarker is already selected on page load (e.g., edit form or query param),
    // trigger autofill immediately
    if (this.biomarkerSelectTarget.value) {
      this.autofill()
    }
  }

  autofill() {
    const selectedOption = this.biomarkerSelectTarget.selectedOptions[0]

    if (!selectedOption || !selectedOption.value) {
      // No biomarker selected, clear fields
      this.clearFields()
      return
    }

    // Get biomarker data from option's data attributes
    const unit = selectedOption.dataset.unit
    const refMin = selectedOption.dataset.refMin
    const refMax = selectedOption.dataset.refMax

    // Populate fields with biomarker defaults
    if (unit) {
      this.unitFieldTarget.value = unit
    }

    if (refMin) {
      this.refMinFieldTarget.value = refMin
    }

    if (refMax) {
      this.refMaxFieldTarget.value = refMax
    }
  }

  clearFields() {
    // Clear all auto-filled fields when no biomarker is selected
    this.unitFieldTarget.value = ""
    this.refMinFieldTarget.value = ""
    this.refMaxFieldTarget.value = ""
  }
}
