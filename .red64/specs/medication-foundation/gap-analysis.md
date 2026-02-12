# Gap Analysis: medication-foundation

---
**Purpose**: Analyze the gap between requirements and existing codebase to inform implementation strategy decisions.

**Approach**:
- Provide analysis and options, not final implementation choices
- Offer multiple viable alternatives when applicable
- Flag unknowns and constraints explicitly
- Align with existing patterns and architecture limits
---

## Executive Summary

- **Scope**: 11 requirements covering drug reference data, prescriptions, medications, complex dosing schedules, daily/weekly schedule views, medication logging, adherence history, printable plans, authorization scoping, and navigation/UX -- essentially the entire Phase 1 medication management domain on top of the existing Phase 0 foundation.
- **Key Findings**: The existing codebase provides a solid Phase 0 foundation (User, Profile, Session, authentication, timezone support, Hotwire/Turbo infrastructure, Tailwind CSS, PWA manifest) but contains zero medication-domain assets. All 4 domain models (Drug, Prescription, Medication, MedicationSchedule) and the MedicationLog tracking model must be created from scratch, along with their controllers, views, service objects, and Stimulus controllers.
- **Primary Challenges**: (1) External API integration with OpenFDA/RxNorm for drug lookup requires a new service layer with caching and graceful degradation; (2) Complex schedule modeling with day-of-week variations and per-schedule dosage amounts requires careful schema design; (3) Daily schedule computation (aggregating across medications, schedules, and logs with timezone awareness) is algorithmically non-trivial; (4) Adherence calculation and heatmap visualization add frontend complexity.
- **Recommended Approach**: Option B (Create New Components) -- the medication domain is entirely net-new with no existing components to extend. All models, controllers, views, services, and Stimulus controllers must be created fresh, following established Rails/Hotwire conventions from Phase 0.

## Current State Investigation

### Domain-Related Assets

| Category | Assets Found | Location | Notes |
|----------|--------------|----------|-------|
| Key Modules | User, Profile, Session, Current | `app/models/` | Phase 0 foundation; User has `has_many :sessions` and `has_one :profile` |
| Reusable Components | Authentication concern, SetTimezone concern, AuthenticatedConstraint | `app/controllers/concerns/`, `app/constraints/` | All new controllers inherit auth-by-default and timezone handling |
| Services/Utilities | SessionTestHelper | `test/test_helpers/` | `sign_in_as(user)` helper for controller/integration tests |
| Views/Layout | Application layout, shared navbar, profile form with Turbo Frame | `app/views/` | Navbar has desktop + mobile responsive structure; Turbo Frame pattern established |
| Stimulus Controllers | `nav-toggle` controller | `app/javascript/controllers/` | Only existing Stimulus controller; pattern for registration is clear |
| CSS Framework | Tailwind CSS (via `tailwindcss-rails` gem) | Gemfile + inline classes | No custom CSS files; all styling is utility-class inline in views |
| JavaScript | Importmap with Turbo + Stimulus | `config/importmap.rb`, `app/javascript/` | ESM-based, no bundler; pin pattern established |
| Test Infrastructure | Minitest + Capybara, fixtures for users/profiles/sessions | `test/` | Parallel execution, session test helper, model + controller + system tests |

### Architecture Patterns

- **Dominant patterns**: Standard Rails MVC with thin controllers, model validations and associations, Turbo Frames for partial page updates, Turbo Streams for real-time response rendering. No service objects exist yet in `app/services/`.
- **Naming conventions**: Models singular PascalCase, controllers plural + Controller, tables plural snake_case. Stimulus controllers kebab-case with `_controller.js` suffix.
- **Dependency direction**: Controllers -> Models -> Database. Views use ERB with Turbo tags. Stimulus controllers are standalone JS modules.
- **Testing approach**: Minitest with fixtures, `SessionTestHelper` for authentication in tests, system tests with Capybara/Selenium. Test structure mirrors app structure.
- **CSS approach**: Tailwind CSS utility classes directly in views. No component CSS files. BEM naming conventions from steering are aspirational but currently unused (Tailwind in use instead).

### Integration Surfaces

- **Data models/schemas**: `users` table with `has_secure_password`, `profiles` table with `timezone` field (critical for schedule display), `sessions` table. All new medication tables will reference `users` via `user_id` foreign key.
- **API clients**: None exist. External drug API integration (OpenFDA/RxNorm) will be the first external API client.
- **Auth mechanisms**: Session-based auth via `Authentication` concern. `Current.user` provides request-scoped user access. All controllers require auth by default. `SetTimezone` concern wraps actions with user's timezone. This is directly usable for all new medication controllers.

## Requirements Feasibility Analysis

### Technical Needs (from Requirements)

| Requirement | Technical Need | Category | Complexity |
|-------------|----------------|----------|------------|
| R1: Drug Reference Data | Drug model (name, rxcui, active_ingredients), DrugSearchService for OpenFDA/RxNorm API, drug search Stimulus controller | Data Model + External API + UI | Moderate |
| R2: Prescription Management | Prescription model (user_id, doctor_name, prescribed_date, notes), CRUD controller, index/show/form views, cascading destroy | Data Model + CRUD + UI | Simple |
| R3: Medication Entry | Medication model (prescription_id, drug_id, dosage, form, instructions, active status), nested CRUD under prescription, drug autocomplete Stimulus + Turbo Frame | Data Model + CRUD + UI | Moderate |
| R4: Complex Dosing Schedules | MedicationSchedule model (medication_id, time_of_day, days_of_week, dosage_amount, instructions), schedule builder Stimulus controller, multi-schedule form | Data Model + UI | Moderate |
| R5: Daily Schedule View | DailyScheduleQuery (join medications/schedules/logs, filter by date, group by time), timezone-aware calculation, status indicators, day navigation | Query + Logic + UI | Complex |
| R6: Weekly Schedule Overview | WeeklyScheduleQuery (7-day aggregation), Turbo Frame loading, week navigation, adherence status per day | Query + UI | Moderate |
| R7: Medication Tracking | MedicationLog model (medication_id, schedule_id, status, logged_at, scheduled_date, reason), Turbo Stream quick-action buttons, idempotent upsert logic, undo capability | Data Model + Logic + UI | Moderate |
| R8: Adherence History | Adherence calculation service, configurable time periods, calendar heatmap visualization, per-medication statistics | Logic + UI | Complex |
| R9: Printable Medication Plan | Print-optimized CSS layout, organized view by time-of-day groups, browser print function trigger | UI + CSS | Simple |
| R10: Data Scoping & Auth | Scoped queries (`Current.user.prescriptions`), strong parameters, not-found responses for unauthorized access | Logic + Security | Simple |
| R11: Navigation & UX | Navbar updates, mobile-first responsive layout (320px+), flash messages, Turbo navigation loading indicator | UI + UX | Simple |

### Gap Analysis

| Requirement | Gap Type | Description | Impact |
|-------------|----------|-------------|--------|
| R1 | Missing | No Drug model, no external API service, no drug search UI exists | High -- foundational model for entire feature |
| R1 | Unknown | OpenFDA vs RxNorm API selection: rate limits, response format, reliability, Ruby HTTP client choice | Medium -- requires research in design phase |
| R1 | Unknown | Caching strategy for drug data (local DB cache vs Rails cache vs hybrid) | Medium -- affects performance and offline behavior |
| R2 | Missing | No Prescription model or CRUD controllers/views | High -- second foundational model |
| R3 | Missing | No Medication model, no drug autocomplete UI component | High -- links prescriptions to drugs |
| R3 | Unknown | Stimulus autocomplete pattern: build custom vs use existing library (e.g., stimulus-autocomplete) | Medium -- design decision for drug search UX |
| R4 | Missing | No MedicationSchedule model, no schedule builder UI | High -- complex schema with day-of-week array and per-schedule dosage |
| R4 | Unknown | Day-of-week storage format: integer bitmask vs JSON array vs separate columns vs serialized array | Medium -- schema design decision |
| R5 | Missing | No daily schedule view, no schedule computation logic | High -- primary user-facing feature |
| R5 | Constraint | Timezone handling exists via `SetTimezone` concern but schedule computation must correctly handle timezone edge cases (DST transitions, midnight crossings) | Medium |
| R6 | Missing | No weekly view or weekly aggregation query | Medium -- builds on daily logic |
| R7 | Missing | No MedicationLog model, no logging UI, no idempotent upsert logic | High -- core tracking functionality |
| R7 | Unknown | Idempotent log upsert: unique composite index vs `find_or_create_by` vs custom service logic | Low -- straightforward with Rails patterns |
| R8 | Missing | No adherence calculation, no heatmap visualization | Medium -- significant frontend work |
| R8 | Unknown | Calendar heatmap implementation: pure CSS/HTML vs JavaScript charting library vs SVG | Medium -- frontend technology decision |
| R9 | Missing | No print-optimized CSS | Low -- minimal complexity |
| R10 | Constraint | Auth exists but no scoped resource pattern is established yet (no `Current.user.X` patterns beyond `profile`) | Low -- pattern is clear from steering docs |
| R11 | Missing | Navigation links for medication features not in navbar, no loading indicator | Low -- straightforward additions |

## Implementation Approach Options

### Option A: Extend Existing Components

**When to consider**: NOT applicable for this feature. There are no existing medication-domain components to extend. The only "extension" would be:

**Files/Modules to Extend**:
| File | Change Type | Impact Assessment |
|------|-------------|-------------------|
| `app/models/user.rb` | Add `has_many :prescriptions` association | Low impact, standard Rails pattern |
| `app/views/shared/_navbar.html.erb` | Add medication navigation links | Low impact, additive change |
| `app/views/dashboard/show.html.erb` | Add medication summary/widget | Low impact, additive change |
| `config/routes.rb` | Add medication resource routes | Low impact, additive change |
| `config/importmap.rb` | Pin new Stimulus controllers | Low impact, additive change |

**Trade-offs**:
- These extensions are unavoidable regardless of approach chosen
- They are integration points, not the core implementation
- Does not address the bulk of work (all new models, controllers, views, services)

**Verdict**: Option A alone is insufficient. The medication domain does not exist.

### Option B: Create New Components

**When to consider**: This is the primary approach. The medication domain is entirely new.

**New Components Required**:
| Component | Responsibility | Integration Points |
|-----------|----------------|-------------------|
| `Drug` model | Drug reference data storage and search | Used by Medication model |
| `Prescription` model | Prescription CRUD, user-scoped | `belongs_to :user`, `has_many :medications` |
| `Medication` model | Medication within prescription, linked to drug | `belongs_to :prescription`, `belongs_to :drug` |
| `MedicationSchedule` model | Schedule entries per medication | `belongs_to :medication` |
| `MedicationLog` model | Daily dose tracking records | `belongs_to :medication`, `belongs_to :medication_schedule` |
| `PrescriptionsController` | Prescription CRUD actions | Scoped to `Current.user` |
| `MedicationsController` | Medication CRUD, nested under prescription | Turbo Frame responses |
| `MedicationSchedulesController` | Schedule CRUD, nested under medication | Stimulus-driven dynamic form |
| `MedicationLogsController` | Log taken/skipped actions | Turbo Stream responses |
| `SchedulesController` (or `DailyScheduleController`) | Daily + weekly schedule views | Query objects for aggregation |
| `AdherenceController` | Adherence history and statistics | Calculation service |
| `DrugSearchService` | External API integration (OpenFDA/RxNorm) | HTTP client, caching |
| `DailyScheduleQuery` (or service) | Compute daily medication schedule | Joins across 4 tables with timezone |
| `AdherenceCalculationService` | Compute adherence percentages | MedicationLog aggregation |
| `drug-search_controller.js` | Stimulus controller for autocomplete | Turbo Frame or fetch for search |
| `schedule-builder_controller.js` | Stimulus controller for dynamic schedule form | Nested fields management |
| `medication-log_controller.js` | Stimulus controller for quick-action buttons | Turbo Stream integration |
| Print CSS | Print-optimized stylesheet | `@media print` rules |
| ~5 database migrations | Drug, Prescription, Medication, MedicationSchedule, MedicationLog tables | Foreign keys, indexes |
| Fixtures | Test data for all new models | Reference existing user fixtures |

**Trade-offs**:
- Clean separation of concerns with each component having clear responsibility
- Easier to test in isolation (model tests, service tests, controller tests)
- Follows established Rails conventions visible in Phase 0
- Many new files to create (estimated 40-60 files including tests)
- Requires careful interface design between components (especially schedule computation)

### Option C: Hybrid Approach

**When to consider**: This is effectively what Option B becomes in practice -- all new domain components with minimal extensions to existing files.

**Combination Strategy**:
| Part | Approach | Rationale |
|------|----------|-----------|
| Domain models (Drug, Prescription, Medication, MedicationSchedule, MedicationLog) | Create New | No existing medication domain |
| Controllers (Prescriptions, Medications, Schedules, Logs, Adherence) | Create New | Distinct resource endpoints |
| User model | Extend | Add `has_many :prescriptions` |
| Navigation | Extend | Add links to shared navbar |
| Dashboard | Extend | Add medication summary widget |
| Routes | Extend | Add nested resource routes |
| Services (DrugSearch, DailySchedule, Adherence) | Create New | First services in `app/services/` |
| Stimulus controllers (drug-search, schedule-builder, medication-log) | Create New | New interactive behaviors |
| Print CSS | Create New | New print stylesheet |

**Phased Implementation** (suggested):
- **Phase 1a**: Models + Migrations + Validations + Associations (Drug, Prescription, Medication, MedicationSchedule, MedicationLog)
- **Phase 1b**: Prescription CRUD + Medication CRUD with drug search
- **Phase 1c**: Schedule management (MedicationSchedule CRUD + schedule builder)
- **Phase 1d**: Daily/Weekly views + MedicationLog tracking
- **Phase 1e**: Adherence history + Printable plan + Navigation polish

**Trade-offs**:
- Balanced approach that acknowledges both new creation and existing integration
- Allows iterative delivery with each phase being testable
- More complex planning but clearer milestones
- This is effectively Option B with a phased delivery strategy

## Effort and Risk Assessment

### Effort Estimate

| Option | Effort | Justification |
|--------|--------|---------------|
| A | N/A | Option A alone is insufficient |
| B | L (1-2 weeks) | 5 new models, 5+ controllers, 10+ view templates, 3 services, 3+ Stimulus controllers, comprehensive tests. All new domain code but follows established Rails patterns. |
| C (Hybrid/Phased) | L (1-2 weeks) | Same scope as B with explicit phasing. Individual phases are S-M each. |

**Effort Scale**:
- **S** (1-3 days): Existing patterns, minimal dependencies, straightforward integration
- **M** (3-7 days): Some new patterns/integrations, moderate complexity
- **L** (1-2 weeks): Significant functionality, multiple integrations or workflows
- **XL** (2+ weeks): Architectural changes, unfamiliar tech, broad impact

### Risk Assessment

| Option | Risk | Justification |
|--------|------|---------------|
| A | N/A | Not viable as standalone |
| B | Medium | New external API integration (OpenFDA/RxNorm) is the primary risk. All other work follows known Rails/Hotwire patterns. Schedule computation with timezone awareness requires careful design. Calendar heatmap is a frontend unknown. No architectural shifts required. |
| C (Hybrid/Phased) | Medium | Same risk profile as B. Phasing reduces delivery risk by allowing early validation. |

**Risk Factors**:
- **External API (OpenFDA/RxNorm)**: Rate limits, availability, response format, and the fallback to manual entry need design-phase research. Risk is mitigated by R1.6 (graceful degradation if API unavailable).
- **Schedule computation**: The daily schedule aggregation across medications, schedules, and logs with timezone awareness is the most algorithmically complex part. Risk is manageable with clear query object design.
- **Calendar heatmap**: Frontend visualization decision (CSS-only vs JS library vs SVG). Moderate risk depending on chosen approach.
- **Day-of-week storage**: Schema design choice that affects query patterns. Low risk but needs early decision.

## Recommendations for Design Phase

### Preferred Approach

**Recommended Option**: C (Hybrid/Phased) -- functionally identical to B but with explicit phased delivery.

**Rationale**:
- The medication domain is entirely new; there is nothing meaningful to extend.
- All new components follow established Rails 8.1 / Hotwire conventions already visible in Phase 0.
- Phased delivery allows early integration testing and user feedback.
- The `app/services/` directory will be created for the first time with DrugSearchService, establishing patterns for future services.
- Existing infrastructure (auth, timezone, Turbo, Stimulus, Tailwind) is fully reusable.

### Key Decisions Required

1. **External Drug API choice**: OpenFDA vs RxNorm REST API -- which is the primary source? What is the fallback strategy? Determine rate limits and caching approach.
2. **Day-of-week storage format**: Integer bitmask (compact, query-friendly), JSON/array column (readable, flexible), or normalized table (most relational but more joins).
3. **Stimulus autocomplete approach**: Custom-built Stimulus controller vs existing library (e.g., `stimulus-autocomplete` package). Affects importmap configuration and bundle complexity.
4. **Calendar heatmap implementation**: Pure CSS/HTML grid, inline SVG, or a JavaScript charting library. Affects frontend dependency footprint.
5. **Schedule computation placement**: Query object in `app/queries/` vs service object in `app/services/` vs model scope. Affects testability and code organization.
6. **Nested routing strategy**: `prescriptions/:id/medications` vs flat routing with params. Affects URL structure and controller organization.

### Research Items to Carry Forward

| Item | Priority | Reason |
|------|----------|--------|
| OpenFDA Drug API response format, rate limits, and Ruby HTTP client options | High | Core integration for R1; no existing API clients in project |
| RxNorm REST API as alternative/complement to OpenFDA | High | Need to determine primary vs fallback data source |
| `stimulus-autocomplete` or similar Importmap-compatible autocomplete library | Medium | Drug search UX for R1 and R3; avoid reinventing autocomplete |
| Calendar heatmap rendering approaches without heavy JS dependencies | Medium | Adherence history visualization for R8; must work with Importmap |
| SQLite JSON column support for day-of-week storage | Low | If JSON array is chosen for schedule days; SQLite has JSON1 extension |
| Print CSS best practices with Tailwind CSS | Low | R9 printable plan; Tailwind has `print:` variant |

## Out of Scope

Items explicitly deferred to design phase:
- Detailed database schema design (exact column types, index strategy, constraint definitions)
- API endpoint response mapping and data transformation logic
- Detailed Stimulus controller API design and event flow
- View template structure and partial decomposition
- Exact Turbo Frame/Stream boundaries for each CRUD flow
- Performance optimization strategy (N+1 prevention, caching, eager loading)
- Detailed test plan and fixture design for medication domain
- Error handling strategy for external API failures
- Migration rollback strategy
