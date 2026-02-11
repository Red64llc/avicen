import { Autocomplete } from "stimulus-autocomplete"

// Wraps stimulus-autocomplete with the drug search endpoint URL.
//
// Extends the Autocomplete controller with a default URL pointing to the
// /drugs/search endpoint. The parent class handles all autocomplete behavior:
// debounced input, fetching results, dropdown rendering, and hidden input
// value capture.
//
// Stimulus automatically merges static values from parent and child classes
// through the prototype chain, so only overridden defaults need to be declared.
//
// Usage:
//   <div data-controller="drug-search"
//        data-drug-search-url-value="/drugs/search"
//        data-drug-search-min-length-value="2"
//        role="combobox">
//     <input type="text"
//            data-drug-search-target="input"
//            placeholder="Search for a drug..." />
//     <input type="hidden"
//            name="medication[drug_id]"
//            data-drug-search-target="hidden" />
//     <ul data-drug-search-target="results"></ul>
//   </div>
//
// Targets (inherited from Autocomplete):
//   - input:   The visible text field the user types into
//   - hidden:  Stores the selected Drug ID for form submission
//   - results: Container where server-fetched <li> items are rendered
//
// Values:
//   - url:        URL for search endpoint (default: "/drugs/search")
//   - minLength:  Minimum characters before search triggers (default: 2)
//   - delay:      Debounce delay in ms (default: 300)
//   - queryParam: URL parameter name for search term (default: "q")
//
// Requirements: 1.4, 3.5
export default class extends Autocomplete {
  static values = {
    url: { type: String, default: "/drugs/search" },
    minLength: { type: Number, default: 2 }
  }
}
