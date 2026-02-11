import { Autocomplete } from "stimulus-autocomplete"

// Wraps stimulus-autocomplete with the drug search endpoint URL.
// Usage:
//   <div data-controller="drug-search" data-drug-search-url-value="/drugs/search" role="combobox">
//     <input type="text" data-drug-search-target="input" />
//     <input type="hidden" name="medication[drug_id]" data-drug-search-target="hidden" />
//     <ul data-drug-search-target="results" class="hidden"></ul>
//   </div>
export default class extends Autocomplete {
  static values = {
    ...Autocomplete.values,
    url: { type: String, default: "/drugs/search" },
    minLength: { type: Number, default: 2 },
    delay: { type: Number, default: 300 },
    queryParam: { type: String, default: "q" }
  }
}
