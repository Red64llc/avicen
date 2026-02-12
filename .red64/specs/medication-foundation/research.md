# Research & Design Decisions: medication-foundation

---
**Purpose**: Capture discovery findings, architectural investigations, and rationale that inform the technical design.

**Usage**:
- Log research activities and outcomes during the discovery phase.
- Document design decision trade-offs that are too detailed for `design.md`.
- Provide references and evidence for future audits or reuse.
---

## Summary
- **Feature**: `medication-foundation`
- **Discovery Scope**: New Feature (greenfield domain on existing Phase 0 foundation)
- **Key Findings**:
  - RxNorm REST API is the preferred drug data source: free, no API key required, returns RxCUI identifiers directly, and permits 20 requests/second/IP.
  - OpenFDA NDC API serves as a complementary data source but is less suited for real-time drug search (designed for regulatory data, not clinical lookup).
  - `stimulus-autocomplete` (1.5 kB) is importmap-compatible and provides server-driven autocomplete out of the box, fitting the existing Hotwire stack without a bundler.
  - A JSON array column in SQLite (via `serialize :days_of_week, coder: JSON` on a text column) is the simplest, most readable approach for storing day-of-week selections per schedule entry.
  - A pure CSS/HTML calendar heatmap using CSS Grid and CSS custom properties (`--intensity`) is feasible and avoids adding JavaScript chart dependencies.
  - Tailwind CSS natively supports the `print:` variant for print-optimized layouts, requiring no additional plugins or configuration.

## Research Log

### RxNorm REST API for Drug Search

- **Context**: Requirement 1 specifies drug search by name with RxCUI identifiers. The gap analysis flagged OpenFDA vs RxNorm as a key decision.
- **Sources Consulted**:
  - [RxNorm API Documentation](https://lhncbc.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html)
  - [getDrugs endpoint](https://lhncbc.nlm.nih.gov/RxNav/APIs/api-RxNorm.getDrugs.html)
  - [getApproximateMatch endpoint](https://lhncbc.nlm.nih.gov/RxNav/APIs/api-RxNorm.getApproximateMatch.html)
  - [RxNorm Terms of Service](https://lhncbc.nlm.nih.gov/RxNav/TermsofService.html)
  - Live test: `GET https://rxnav.nlm.nih.gov/REST/drugs.json?name=amoxicillin`
- **Findings**:
  - `getDrugs` endpoint accepts a drug name string and returns grouped results by term type (SCD, SBD, GPCK, BPCK).
  - Each result includes `rxcui`, `name`, `synonym`, and `tty` fields.
  - No API key required for standard use; only restricted source names require a UTS key.
  - Rate limit: 20 requests/second/IP. Sufficient for single-user autocomplete.
  - Data is updated monthly following RxNorm releases.
  - `getApproximateMatch` provides fuzzy matching for misspelled terms.
  - JSON response format is natively available (append `.json` to endpoint path).
  - Response structure: `drugGroup.conceptGroup[].conceptProperties[].{rxcui, name, synonym, tty}`.
- **Implications**:
  - RxNorm is the primary drug data source. No API key management overhead.
  - The `getDrugs` endpoint handles the autocomplete use case directly.
  - Local caching of previously fetched drugs in the `drugs` table eliminates repeated API calls for the same search terms.
  - `getApproximateMatch` can be used as a fallback for terms that return no results from `getDrugs`.

### OpenFDA Drug NDC API (Complementary Source)

- **Context**: Evaluate as alternative or complement to RxNorm.
- **Sources Consulted**:
  - [OpenFDA APIs](https://open.fda.gov/apis/)
  - [Drug NDC Searchable Fields](https://open.fda.gov/apis/drug/ndc/searchable-fields/)
  - [OpenFDA Fields (openfda object)](https://open.fda.gov/apis/openfda-fields/)
- **Findings**:
  - Endpoint: `GET https://api.fda.gov/drug/ndc.json?search=brand_name:term+OR+generic_name:term`
  - Response includes `brand_name`, `generic_name`, `active_ingredients`, `dosage_form`, and an `openfda` sub-object with `rxcui` array.
  - Not all records are harmonized (some lack the `openfda.rxcui` field).
  - API key optional but recommended (rate limit: 40 requests/minute without key, 240/minute with key).
  - Max 100 results per request.
  - Designed primarily for regulatory and NDC lookup, not clinical drug search.
- **Implications**:
  - Less suitable as a primary autocomplete source due to regulatory focus and lower rate limits.
  - Potentially useful for enriching drug data (active ingredients, dosage forms) after initial RxNorm-based lookup.
  - Deferred to future enhancement; not included in Phase 1 design.

### stimulus-autocomplete for Drug Search UI

- **Context**: Requirement 3.5 specifies Stimulus-driven drug autocomplete. The gap analysis identified build-vs-buy as a decision point.
- **Sources Consulted**:
  - [stimulus-autocomplete GitHub](https://github.com/afcapel/stimulus-autocomplete)
  - [stimulus-autocomplete npm](https://www.npmjs.com/package/stimulus-autocomplete)
  - [Hotwire discussion on autocomplete](https://discuss.hotwired.dev/t/autocomplete-component-with-stimulus/581)
  - [hotwire_combobox gem](https://github.com/josefarias/hotwire_combobox)
- **Findings**:
  - `stimulus-autocomplete` is 1.5 kB compressed, importmap-compatible (`./bin/importmap pin stimulus-autocomplete`).
  - Server returns HTML fragments (`<li>` elements with `data-autocomplete-value`), which aligns perfectly with the Rails/Turbo server-rendering approach.
  - Supports hidden input for storing the selected value (drug ID), text input for display.
  - Can be subclassed to customize URL building.
  - `hotwire_combobox` is an alternative Rails gem but is still pre-beta with an unstable API.
- **Implications**:
  - `stimulus-autocomplete` is the selected approach. Lightweight, stable, importmap-compatible, server-driven.
  - The server endpoint returns HTML `<li>` fragments, not JSON. This keeps the pattern consistent with Hotwire philosophy.
  - The drug search controller endpoint returns search results as HTML fragments rendered by a partial.

### Day-of-Week Storage Strategy

- **Context**: Requirement 4 requires schedules with day-of-week selections. Schema design decision for MedicationSchedule.
- **Sources Consulted**:
  - [Enhancing Rails SQLite: Array Columns](https://fractaledmind.com/2023/09/12/enhancing-rails-sqlite-array-columns/)
  - [SQLite JSON Functions](https://www.sqlite.org/json1.html)
  - [Querying SQLite JSON columns in Rails](https://www.erikminkel.com/2020/11/13/query-sqlite3-json-columns-in-rails/)
- **Findings**:
  - **Option A -- Integer bitmask**: Compact (single integer), query-friendly with bitwise operations. Less readable. Example: 42 = Monday + Wednesday + Friday (bits 1, 3, 5).
  - **Option B -- JSON array in text column**: Readable (`[1,3,5]`), Rails `serialize` support, SQLite JSON1 functions available. Slightly more storage but trivial for this data size.
  - **Option C -- Separate join table**: Fully normalized. Overkill for 0-7 values per schedule. Adds unnecessary joins.
  - SQLite JSON1 extension is available by default in modern SQLite3 builds. `json_each()` can decompose arrays for queries.
  - Rails `serialize :column, coder: JSON` handles transparent Ruby Array to JSON string conversion.
- **Implications**:
  - **Selected: Option B (JSON array in text column)**. Readable, queryable with SQLite JSON functions, matches Rails conventions.
  - Integer representation: 0 = Sunday, 1 = Monday, ..., 6 = Saturday (matching Ruby's `Date::DAYNAMES` and `wday` convention).
  - Model accessor provides helper methods for human-readable day names.

### Calendar Heatmap for Adherence Visualization

- **Context**: Requirement 8.3 requires a calendar heatmap showing daily adherence. Frontend technology decision.
- **Sources Consulted**:
  - [Pure CSS Heatmaps (Artur Bien)](https://expensive.toys/blog/pure-CSS-heatmap)
  - [Cal-Heatmap library](https://cal-heatmap.com/)
  - [CSS Grid calendar patterns](https://freefrontend.com/css-grid/)
- **Findings**:
  - **Pure CSS approach**: CSS Grid for 7-column layout, CSS custom properties (`--intensity: 0.0` to `1.0`), `color-mix()` or HSL for gradient. Data embedded in `style` attributes from server.
  - **JavaScript libraries** (Cal-Heatmap, D3-based): More features but add dependency weight and complexity. Not importmap-friendly without bundler.
  - Pure CSS approach works with server-rendered data. Each day cell receives an inline `style="--intensity: 0.85"` from the ERB template, and CSS handles the color mapping.
  - Tailwind utility classes can be combined with a small custom CSS rule for the intensity-to-color mapping.
- **Implications**:
  - **Selected: Pure CSS/HTML with CSS Grid**. No JavaScript dependency. Server computes adherence percentages and embeds them as CSS custom properties.
  - A small custom CSS block (under 20 lines) handles the intensity-to-color mapping. All other layout uses Tailwind utilities.
  - Clicking a day cell navigates to the daily detail view via standard Turbo links.

### Print Layout with Tailwind CSS

- **Context**: Requirement 9 requires a print-optimized medication plan.
- **Sources Consulted**:
  - [Tailwind CSS Print Guide](https://www.tutorialpedia.org/blog/tailwind-css-print/)
  - [CSS Print Styles with Tailwind](https://www.jacobparis.com/content/css-print-styles)
- **Findings**:
  - Tailwind CSS natively supports `print:` variant (e.g., `print:hidden`, `print:block`, `print:text-black`, `print:bg-white`).
  - No additional configuration or plugin needed in modern Tailwind (v3+).
  - `print:hidden` on navigation, footer, and interactive elements. `print:block` on print-only content.
  - The `@media print` rules are generated automatically by Tailwind when `print:` prefixed classes are used.
- **Implications**:
  - Print layout uses inline Tailwind `print:` classes directly in the view templates.
  - A dedicated printable view partial renders the medication plan in a print-friendly format.
  - Browser's native `window.print()` is triggered by a simple button.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Standard Rails MVC | Models, controllers, views with service objects for complex logic | Matches existing Phase 0 patterns, simple to understand, well-documented | Can become complex with deeply nested resources | Selected approach |
| Query Objects | Dedicated classes in `app/queries/` for complex SQL aggregation | Clean separation of query logic from models | Adds new directory convention | Used for daily/weekly schedule computation |
| Service Objects | Classes in `app/services/` for external API calls and business logic | Testable in isolation, single responsibility | First services in the project, establishes new pattern | Used for DrugSearchService and AdherenceCalculationService |

## Design Decisions

### Decision: RxNorm as Primary Drug API

- **Context**: Need an external drug database for drug search autocomplete with RxCUI identifiers.
- **Alternatives Considered**:
  1. OpenFDA Drug NDC API -- regulatory focus, lower rate limits, inconsistent RxCUI coverage.
  2. RxNorm REST API -- clinical drug terminology, direct RxCUI results, higher rate limits, no key required.
  3. Both in parallel -- adds complexity, unclear benefit for Phase 1.
- **Selected Approach**: RxNorm `getDrugs` endpoint as the sole external API for Phase 1.
- **Rationale**: Direct RxCUI results, no API key management, 20 req/sec rate limit is adequate, clinical drug terminology matches user expectations for medication names.
- **Trade-offs**: RxNorm data is US-centric. International drug names may not be found. Manual entry fallback (Requirement 1.6) mitigates this.
- **Follow-up**: Evaluate OpenFDA as an enrichment source in a future phase.

### Decision: stimulus-autocomplete for Drug Search

- **Context**: Need an autocomplete component for drug name search that works with Hotwire and importmaps.
- **Alternatives Considered**:
  1. Custom Stimulus controller -- full control but reinvents standard autocomplete behavior.
  2. `stimulus-autocomplete` -- lightweight, importmap-compatible, server-driven.
  3. `hotwire_combobox` gem -- Rails-integrated but pre-beta, unstable API.
- **Selected Approach**: `stimulus-autocomplete` library.
- **Rationale**: 1.5 kB, stable, importmap-compatible, server returns HTML fragments (Hotwire philosophy), well-documented with clear extension points.
- **Trade-offs**: Server renders HTML fragments for results instead of JSON. This is actually a benefit for the Hotwire approach.
- **Follow-up**: None. Library is stable and widely used.

### Decision: JSON Array for Day-of-Week Storage

- **Context**: MedicationSchedule needs to store which days of the week a schedule applies to.
- **Alternatives Considered**:
  1. Integer bitmask -- compact but low readability, bitwise operations needed.
  2. JSON array in text column -- readable, queryable with SQLite JSON functions.
  3. Separate join table -- over-engineered for 7 possible values.
- **Selected Approach**: Text column with `serialize :days_of_week, coder: JSON`.
- **Rationale**: Human-readable in database, transparent Array conversion in Ruby, queryable with `json_each()` for schedule lookups by day.
- **Trade-offs**: Slightly less efficient than bitmask for bitwise queries, but query performance is negligible with SQLite's low-latency local access.
- **Follow-up**: If day-of-week filtering becomes a hot path, consider adding a generated column with index.

### Decision: Pure CSS Calendar Heatmap

- **Context**: Adherence history requires a calendar heatmap visualization (Requirement 8.3).
- **Alternatives Considered**:
  1. Cal-Heatmap (JS library) -- feature-rich but adds a heavyweight dependency not easily importmap-compatible.
  2. SVG-based custom solution -- flexible but more code to maintain.
  3. Pure CSS Grid with CSS custom properties -- no JS, server-rendered, Tailwind-compatible.
- **Selected Approach**: Pure CSS/HTML heatmap with CSS Grid.
- **Rationale**: Zero JavaScript dependencies, server-side computation of adherence percentages, consistent with Hotwire philosophy of server-rendered HTML, small amount of custom CSS.
- **Trade-offs**: Less interactive than a JS library (no hover tooltips by default). Clicking a day cell links to the daily view for details, which provides equivalent functionality.
- **Follow-up**: Consider adding simple CSS `:hover` pseudo-element tooltips for percentage display.

### Decision: Nested Resource Routing for Prescriptions and Medications

- **Context**: Medications belong to prescriptions. Schedules belong to medications. URL structure decision.
- **Alternatives Considered**:
  1. Deeply nested: `/prescriptions/:id/medications/:id/schedules/:id` -- clear hierarchy but long URLs.
  2. Shallow nesting: nest only for create/index, flat for show/edit/delete.
  3. Flat routing with query params -- loses hierarchical context.
- **Selected Approach**: Rails `shallow: true` nesting.
- **Rationale**: `shallow: true` generates nested routes for collection actions (index, new, create) and flat routes for member actions (show, edit, update, destroy). This keeps URLs short while preserving hierarchical context for creation.
- **Trade-offs**: Slightly more complex route helpers, but this is a well-established Rails convention.
- **Follow-up**: None. Standard Rails pattern.

### Decision: Query Objects for Schedule Computation

- **Context**: Daily and weekly schedule views require complex multi-table joins with timezone awareness.
- **Alternatives Considered**:
  1. Model scopes -- insufficient for the complexity of cross-model aggregation.
  2. Service objects in `app/services/` -- possible but the primary responsibility is data retrieval, not business logic transformation.
  3. Query objects in `app/queries/` -- purpose-built for complex SQL queries.
- **Selected Approach**: Query objects (`DailyScheduleQuery`, `WeeklyScheduleQuery`) in `app/queries/`.
- **Rationale**: Clear responsibility (complex data retrieval), follows the project structure convention, testable in isolation, reusable across controllers.
- **Trade-offs**: Introduces the `app/queries/` directory for the first time in the project.
- **Follow-up**: Document the query object pattern in steering for future reference.

## Risks & Mitigations

- **RxNorm API Availability** -- The API could be temporarily unavailable. Mitigation: local drug cache in `drugs` table, manual entry fallback (Requirement 1.6), retry with exponential backoff in DrugSearchService.
- **RxNorm Rate Limits (20 req/sec)** -- With multiple concurrent users, rate limits could be hit. Mitigation: debounced autocomplete input (300ms delay), local cache-first strategy reduces API calls significantly.
- **SQLite JSON Query Performance** -- JSON array queries for day-of-week filtering may be slower than integer operations. Mitigation: SQLite's in-process nature eliminates network latency; the data volume (schedules per user) is inherently small. Add generated column + index if profiling shows need.
- **Timezone Edge Cases** -- DST transitions and midnight crossings could cause schedule display errors. Mitigation: use Rails `Time.use_zone` consistently (already implemented in `SetTimezone` concern), store all times in UTC, convert at display time.
- **Calendar Heatmap Accessibility** -- Pure CSS heatmaps may lack screen reader context. Mitigation: add `aria-label` attributes with adherence percentage text on each day cell.

## References

- [RxNorm API Documentation](https://lhncbc.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html) -- Primary drug data API
- [RxNorm getDrugs endpoint](https://lhncbc.nlm.nih.gov/RxNav/APIs/api-RxNorm.getDrugs.html) -- Drug search by name
- [RxNorm Terms of Service](https://lhncbc.nlm.nih.gov/RxNav/TermsofService.html) -- Rate limits and usage terms
- [OpenFDA APIs](https://open.fda.gov/apis/) -- Complementary drug data (deferred)
- [stimulus-autocomplete](https://github.com/afcapel/stimulus-autocomplete) -- Autocomplete Stimulus component
- [Enhancing Rails SQLite: Array Columns](https://fractaledmind.com/2023/09/12/enhancing-rails-sqlite-array-columns/) -- JSON array column pattern
- [SQLite JSON Functions](https://www.sqlite.org/json1.html) -- JSON1 extension reference
- [Pure CSS Heatmaps](https://expensive.toys/blog/pure-CSS-heatmap) -- CSS custom property heatmap technique
- [Tailwind CSS Print Guide](https://www.tutorialpedia.org/blog/tailwind-css-print/) -- Print variant usage
