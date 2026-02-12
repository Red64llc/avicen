# Gap Analysis: Biology Reports

---
**Purpose**: Analyze the gap between requirements and existing codebase to inform implementation strategy decisions.

**Approach**:
- Provide analysis and options, not final implementation choices
- Offer multiple viable alternatives when applicable
- Flag unknowns and constraints explicitly
- Align with existing patterns and architecture limits
---

## Executive Summary

- **Scope**: Implement biology/lab report management with biomarker catalog, test result entry, document attachment, trend visualization, and filtering capabilities
- **Key Findings**: Strong foundation exists with authentication, user-scoped data patterns, Turbo Frames/Streams, Active Storage setup, and service object patterns. No existing charting library; visualization will require JS library selection
- **Primary Challenges**:
  - Biomarker catalog data sourcing and seeding strategy undefined
  - Charting library selection for trend visualization (no existing chart library in stack)
  - Reference range auto-population logic and override UI patterns
  - Out-of-range calculation and visual flagging patterns
- **Recommended Approach**: Hybrid (Option C) - Extend existing patterns (user scoping, Turbo, Active Storage) while creating new domain-specific components (biomarker catalog, biology reports models, charting integration)

## Current State Investigation

### Domain-Related Assets

| Category | Assets Found | Location | Notes |
|----------|--------------|----------|-------|
| **Key Modules** | User, Prescription, Medication, Profile models | `app/models/` | Well-established user-scoped health data patterns |
| **Reusable Components** | Authentication (session-based), Turbo Frames/Streams, Active Storage | `app/controllers/concerns/`, views | Proven patterns for real-time updates and file uploads |
| **Services/Utilities** | DrugSearchService, AdherenceCalculationService | `app/services/` | Service object pattern with Result objects established |
| **UI Components** | Heatmap visualization (adherence), Tailwind CSS styling | `app/views/adherence/` | CSS-only visualization pattern exists (color-mix for heatmap) |
| **Testing Infrastructure** | Minitest with fixtures, WebMock for HTTP stubbing | `test/` | Standard Rails testing patterns |

### Architecture Patterns

- **Dominant patterns**:
  - RESTful controllers with `Current.user` scoping for authorization
  - Service objects with nested Result classes (success?/error? pattern)
  - Turbo Frames for partial updates, Turbo Streams for real-time broadcasts
  - Active Storage for file attachments (configured with local disk storage)
  - Scopes for common queries (`.ordered`, `.active`)
  - Lean models with clear associations, validations in models

- **Naming conventions**:
  - Models: Singular PascalCase (`Prescription`, `Medication`)
  - Controllers: Plural with Controller suffix (`PrescriptionsController`)
  - Tables: Plural snake_case with foreign keys and indexes
  - Services: Action-oriented (`DrugSearchService`)

- **Dependency direction**:
  - Controllers → Services → Models
  - Models define associations and validations only
  - Services handle complex business logic and external integrations
  - Controllers remain thin (set instance variables, render/redirect)

- **Testing approach**:
  - Model tests for validations, associations, scopes
  - Controller tests for HTTP responses and scoping
  - Service tests with mocked dependencies
  - Fixtures for test data (YAML files in `test/fixtures/`)

### Integration Surfaces

- **Data models/schemas**:
  - User model with `has_many :prescriptions`
  - Foreign key constraints with cascade delete (`dependent: :destroy`)
  - Indexed columns for common queries and foreign keys
  - SQLite3 database with Rails 8.1 schema

- **API clients**:
  - External API integration pattern: DrugSearchService → RxNorm API
  - HTTP client: Net::HTTP with timeout configuration
  - Error handling: Rescue specific exceptions, log warnings, return empty results
  - Fallback: Local search → API search → return local results

- **Auth mechanisms**:
  - Session-based authentication via `Authentication` concern
  - `Current.user` for request-scoped user access
  - All resources scoped through user associations
  - Authentication required by default (opt-out with `allow_unauthenticated_access`)

## Requirements Feasibility Analysis

### Technical Needs (from Requirements)

| Requirement | Technical Need | Category | Complexity |
|-------------|----------------|----------|------------|
| **R1: Biomarker Catalog** | Biomarker model with name, code, unit, reference ranges; autocomplete search | Data Model / UI | Moderate |
| **R1: Auto-fill reference** | Service to populate test result form from biomarker catalog | Logic | Simple |
| **R1: Override ranges** | Editable reference range fields in test result form | UI | Simple |
| **R2: Biology Report CRUD** | BiologyReport model, controller, views (user-scoped) | Data Model / UI / API | Simple |
| **R2: User scoping** | Association: User → BiologyReports with authentication | Logic | Simple |
| **R2: Chronological list** | Scope with `order(test_date: :desc)` | Data Model | Simple |
| **R2: Delete cascade** | `dependent: :destroy` on associations | Data Model | Simple |
| **R3: Test Result Entry** | TestResult model, nested forms, validation | Data Model / UI / Logic | Moderate |
| **R3: Out-of-range flag** | Calculation logic comparing value to range, boolean flag | Logic | Simple |
| **R3: Recalculate flag** | Callback or service method on save/update | Logic | Simple |
| **R4: Document Attachment** | Active Storage `has_one_attached`, file validation | Data Model / UI | Simple |
| **R4: File type validation** | Custom validator for PDF/JPEG/PNG | Logic | Simple |
| **R4: Display/download** | View helpers for Active Storage attachments | UI | Simple |
| **R5: Trend Chart** | Line chart with reference range bands, JS charting library | UI / Logic | Complex |
| **R5: Biomarker history** | Query: TestResults for user, grouped by biomarker, ordered by date | Data Model / Logic | Moderate |
| **R5: Visual bands** | Chart.js or similar with annotation plugin for reference ranges | UI | Moderate |
| **R5: Navigate to report** | Links from chart data points to report detail | UI | Simple |
| **R5: Flag out-of-range** | Conditional CSS classes based on flag | UI | Simple |
| **R6: Filter by date/lab** | Form with date range, lab name filters; Turbo Frame updates | UI / Logic | Moderate |
| **R6: Biomarker index** | Query: distinct biomarkers from user's test results | Data Model / Logic | Simple |
| **R7: Data integrity** | Foreign keys, validations, cascade deletes | Data Model | Simple |

### Gap Analysis

| Requirement | Gap Type | Description | Impact |
|-------------|----------|-------------|--------|
| **R1: Biomarker Catalog** | **Missing** | No biomarker model or seed data; need to define data source and seeding strategy | High |
| **R1: Autocomplete** | **Constraint** | Stimulus Autocomplete library already in use (`stimulus-autocomplete`) - can leverage | Low |
| **R5: Charting Library** | **Missing** | No JS charting library in stack; need to select and integrate (Chart.js, ApexCharts, or CSS-only) | High |
| **R5: Reference Range Bands** | **Unknown** | Implementation pattern for shaded regions or lines on chart depends on library capabilities | Medium |
| **R5: Line Chart** | **Unknown** | Best approach for responsive, accessible charts (JS library vs CSS-only) | Medium |
| **R6: Turbo Frame Filtering** | **Constraint** | Existing Turbo Frame pattern established; must follow for consistency | Low |
| **R6: Biomarker Index View** | **Missing** | No existing pattern for "index" or "catalog" views; need new UI pattern | Medium |
| **R7: Numeric Validation** | **Constraint** | Rails numeric validation pattern: `validates :value, numericality: true` | Low |

**Gap Types Summary**:
- **Missing**: Biomarker catalog, charting library, biomarker index UI pattern
- **Unknown**: Charting implementation details, reference range visualization
- **Constraint**: Must use existing Turbo Frame patterns, Stimulus Autocomplete, Rails validation patterns

## Implementation Approach Options

### Option A: Extend Existing Components

**When to consider**: Minimal new domain concepts, fitting naturally into existing structure

**Files/Modules to Extend**:

| File | Change Type | Impact Assessment |
|------|-------------|-------------------|
| `app/models/user.rb` | Add `has_many :biology_reports` | Low - consistent with existing prescription pattern |
| `config/routes.rb` | Add RESTful routes for biology_reports, nested test_results | Low - standard Rails routing |
| `app/views/shared/_navbar.html.erb` | Add "Biology Reports" nav link | Low - UI addition |
| `config/importmap.rb` | Pin charting library (if using JS charts) | Low - standard importmap pattern |
| Stimulus Autocomplete | Reuse for biomarker search | Low - already in use for drug search |

**Trade-offs**:
- ✅ Minimal new files, faster initial development
- ✅ Leverages existing patterns (user scoping, Turbo, Active Storage)
- ✅ Consistent with established architecture
- ❌ Does not address new domain complexity (biomarker catalog, charting)
- ❌ Insufficient for complex features like trend visualization

**Assessment**: This option alone is insufficient. Biology reports introduce substantial new domain concepts (biomarker catalog, test results, trend charts) that cannot be adequately handled by extending existing files.

### Option B: Create New Components

**When to consider**: Distinct domain responsibility requiring new models, services, and UI patterns

**New Components Required**:

| Component | Responsibility | Integration Points |
|-----------|----------------|-------------------|
| `Biomarker` model | Catalog of biomarkers with reference data | Referenced by TestResult |
| `BiologyReport` model | Report metadata (date, lab, notes) | Belongs to User, has_many TestResults |
| `TestResult` model | Individual test value with reference range | Belongs to BiologyReport and Biomarker |
| `BiologyReportsController` | CRUD for biology reports | Scoped through Current.user |
| `TestResultsController` | Nested CRUD for test results | Scoped through BiologyReport |
| `BiomarkerTrendsController` | Trend visualization endpoint | Queries TestResults, renders chart |
| `BiologyReport` views | List, detail, form views with Turbo Frames | Uses existing layout/styling patterns |
| Biomarker seed data | CSV or YAML with common biomarkers | `db/seeds.rb` or separate seed file |
| Charting integration | JS library setup (Chart.js or ApexCharts) | Importmap pin, Stimulus controller |
| `ReferenceRangeCalculator` service (optional) | Calculate out-of-range flags | Called from TestResult model/controller |

**Trade-offs**:
- ✅ Clean separation of concerns (new domain isolated)
- ✅ Easier to test in isolation
- ✅ Follows established patterns (RESTful controllers, service objects)
- ✅ Reduces complexity in existing models
- ❌ More files to navigate
- ❌ Requires careful interface design (biomarker catalog, charting)
- ❌ Larger initial implementation effort

**Assessment**: This option provides a solid foundation but requires careful planning for biomarker catalog seeding, charting library selection, and trend visualization UI.

### Option C: Hybrid Approach

**When to consider**: Complex features requiring both extension and new creation

**Combination Strategy**:

| Part | Approach | Rationale |
|------|----------|-----------|
| **User association** | Extend User model | Add `has_many :biology_reports` (consistent with prescriptions) |
| **Biomarker catalog** | Create new Biomarker model + seed data | Distinct domain entity requiring research for data source |
| **Biology reports domain** | Create new models (BiologyReport, TestResult) | New domain with unique business logic |
| **Controllers/views** | Create new controllers/views following existing patterns | Leverage Turbo, Active Storage, Tailwind patterns |
| **Document attachment** | Extend with Active Storage pattern | Reuse existing Active Storage setup |
| **Autocomplete** | Reuse Stimulus Autocomplete | Apply existing pattern to biomarker search |
| **Charting** | Create new Stimulus controller + integrate JS library | New capability requiring library selection |
| **Services** | Create domain-specific services if needed | Follow DrugSearchService pattern |
| **Testing** | Create new test files following existing patterns | Minitest with fixtures, WebMock for any external APIs |

**Phased Implementation**:

**Phase 1: Core CRUD (Minimal Viable)**
1. Create Biomarker model with seed data (10-20 common biomarkers)
2. Create BiologyReport and TestResult models with associations
3. Implement CRUD controllers and views (list, create, edit, delete)
4. Add document attachment with Active Storage
5. Implement basic filtering (date range, lab name)

**Phase 2: Advanced Features**
1. Integrate biomarker autocomplete search
2. Implement reference range auto-fill and override
3. Calculate and display out-of-range flags
4. Add biomarker index view

**Phase 3: Visualization**
1. Research and select charting library (Chart.js recommended)
2. Implement biomarker trend chart with reference bands
3. Add navigation from chart to report detail
4. Polish UI with visual distinction for out-of-range values

**Risk Mitigation**:
- Start with CSS-only visualization (like adherence heatmap) if charting library integration is complex
- Seed biomarker catalog with minimal data (10-20 common tests), expand later
- Implement document attachment after core CRUD is stable
- Use feature flags or environment checks for charting features during development

**Trade-offs**:
- ✅ Balanced approach for complex features
- ✅ Allows iterative refinement (phased implementation)
- ✅ Leverages existing patterns where applicable
- ✅ Creates new components for distinct domain concerns
- ❌ More complex planning required
- ❌ Potential for inconsistency if not well-coordinated
- ❌ Requires discipline to follow established patterns

**Assessment**: This is the recommended approach. It leverages existing infrastructure (user scoping, Turbo, Active Storage, Stimulus Autocomplete) while creating new domain-specific components. Phased implementation reduces risk and allows for iterative refinement.

## Effort and Risk Assessment

### Effort Estimate

| Option | Effort | Justification |
|--------|--------|---------------|
| **A: Extend** | S (1-3 days) | Insufficient - does not address core requirements (biomarker catalog, charting) |
| **B: Create New** | L (1-2 weeks) | Full greenfield implementation with biomarker catalog research, charting integration, multiple models/controllers/views |
| **C: Hybrid** | M-L (5-10 days) | Phased approach reduces complexity: Phase 1 (3-4 days CRUD), Phase 2 (2-3 days autocomplete/flags), Phase 3 (2-3 days charting) |

**Effort Scale**:
- **S** (1-3 days): Existing patterns, minimal dependencies, straightforward integration
- **M** (3-7 days): Some new patterns/integrations, moderate complexity
- **L** (1-2 weeks): Significant functionality, multiple integrations or workflows
- **XL** (2+ weeks): Architectural changes, unfamiliar tech, broad impact

### Risk Assessment

| Option | Risk | Justification |
|--------|------|---------------|
| **A: Extend** | **High** | Inadequate for requirements; would require significant rework |
| **B: Create New** | **Medium** | Clear separation reduces coupling risk, but requires correct upfront design; charting library selection adds uncertainty |
| **C: Hybrid** | **Low-Medium** | Leverages proven patterns, phased approach allows course correction; primary risks are biomarker data sourcing and charting library compatibility |

**Risk Factors**:
- **High**: Unknown tech, complex integrations, architectural shifts, unclear perf/security path
- **Medium**: New patterns with guidance, manageable integrations, known perf solutions
- **Low**: Extend established patterns, familiar tech, clear scope, minimal integration

**Specific Risks for Biology Reports Feature**:
1. **Biomarker Catalog Data** (Medium Risk): Need to define authoritative source for biomarker reference data (research item)
2. **Charting Library Selection** (Medium Risk): Must balance bundle size, accessibility, Rails compatibility (research item)
3. **Reference Range Complexity** (Low Risk): Business logic is straightforward (min/max comparison)
4. **Active Storage Configuration** (Low Risk): Already configured and used in similar Rails projects
5. **Turbo Frame Filtering** (Low Risk): Established pattern exists in codebase
6. **Performance** (Low Risk): User-scoped queries with proper indexes should scale

## Recommendations for Design Phase

### Preferred Approach

**Recommended Option**: **C - Hybrid Approach**

**Rationale**:
- Balances leveraging existing infrastructure with creating new domain-specific components
- Phased implementation allows for iterative refinement and early validation
- Follows established patterns (user scoping, Turbo, Active Storage) reducing learning curve
- Creates clean separation for new domain (biomarkers, biology reports, test results)
- Allows charting library selection to be deferred to Phase 3 after core functionality is validated

### Key Decisions Required

1. **Biomarker Catalog Data Source**
   - Define authoritative source for biomarker reference data (LOINC codes? Custom curated list?)
   - Decide on initial seed data scope (10-20 common tests vs comprehensive catalog)
   - Determine update strategy (manual vs API-driven)

2. **Charting Library Selection**
   - Evaluate options: Chart.js, ApexCharts, or CSS-only approach
   - Criteria: Bundle size, accessibility, mobile responsiveness, Rails/importmap compatibility, annotation support for reference ranges
   - Consider fallback: CSS-only heatmap-style visualization (like adherence view) if JS library integration is complex

3. **Reference Range Auto-fill UI Pattern**
   - Decide on UX: Pre-populate form fields (editable) vs show suggestions with "Use default" button
   - Determine storage: Store both default and override ranges? Or just final range?

4. **Out-of-Range Visual Flagging**
   - Define visual treatment: Color coding, icons, badges, or combination
   - Ensure accessibility (not color-only, sufficient contrast)

5. **Biomarker Index View**
   - Decide on UI pattern: Grid of cards, table, or list
   - Determine sorting/filtering needs (alphabetical, frequency, category)

### Research Items to Carry Forward

| Item | Priority | Reason |
|------|----------|--------|
| **Biomarker catalog data source** | **High** | Blocks Biomarker model design and seed data creation; requires decision on LOINC codes, custom list, or external API |
| **Charting library evaluation** | **High** | Impacts design phase decisions on visualization; need bundle size, accessibility, Rails compatibility analysis |
| **Reference range sources** | **Medium** | Default ranges for common tests; may use medical literature, existing databases, or allow user-defined only |
| **Active Storage PDF rendering** | **Low** | Investigate Rails/browser capabilities for in-page PDF viewing (vs download-only) |
| **Biomarker autocomplete performance** | **Low** | Test Stimulus Autocomplete with 100+ biomarkers; may need debouncing or pagination |
| **Test result bulk entry UX** | **Low** | Explore patterns for entering multiple test results efficiently (single form, batch import, etc.) |

## Out of Scope

Items explicitly deferred to design phase:
- **Biomarker catalog seeding strategy**: Exact data source, structure, and initial data set
- **Charting library implementation details**: Specific configuration, styling, responsiveness
- **Advanced filtering**: Beyond date range and lab name (e.g., by biomarker category, out-of-range only)
- **Test result import/parsing**: OCR or structured data import from lab reports (future enhancement)
- **Multi-user access**: Sharing reports with doctors or caregivers (future enhancement)
- **Export functionality**: PDF generation, CSV export of test results (future enhancement)
- **Biomarker categories/grouping**: Organizing biomarkers by organ system or test panel (future enhancement)
- **Historical range tracking**: Storing changes to reference ranges over time (future enhancement)
