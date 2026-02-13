# Gap Analysis: Document Scanning

---
**Purpose**: Analyze the gap between requirements and existing codebase to inform implementation strategy decisions.

**Approach**:
- Provide analysis and options, not final implementation choices
- Offer multiple viable alternatives when applicable
- Flag unknowns and constraints explicitly
- Align with existing patterns and architecture limits
---

## Executive Summary

- **Scope**: AI-powered document scanning for prescriptions and biology reports using Claude Vision API, with camera capture, extraction review, and database persistence
- **Key Finding**: Strong foundation exists with models (Prescription, BiologyReport, Drug, Biomarker), Active Storage, Turbo/Stimulus patterns, and comprehensive steering for LLM integration
- **Primary Challenges**: ruby_llm gem not yet installed; new scanner services, background jobs, and camera capture UI needed; no existing LLM services to extend
- **Missing Critical Component**: The `ruby_llm` gem is referenced in steering but not present in Gemfile - must be added
- **Recommended Approach**: Hybrid - extend existing models with attachment support while creating new dedicated scanner services and scan flow controllers

## Current State Investigation

### Domain-Related Assets

| Category | Assets Found | Location | Notes |
|----------|--------------|----------|-------|
| **Prescription Models** | Prescription, Medication, MedicationSchedule, Drug | `app/models/` | Complete prescription hierarchy exists, no attachment support yet |
| **Biology Report Models** | BiologyReport, TestResult, Biomarker | `app/models/` | BiologyReport already has `has_one_attached :document` |
| **Services** | DrugSearchService, OutOfRangeCalculator, AdherenceCalculationService | `app/services/` | Result object pattern established (DrugSearchService) |
| **Validators** | DocumentValidator | `app/validators/` | Validates PDF, JPEG, PNG - can be extended for HEIC |
| **Stimulus Controllers** | drug_search_controller, biomarker_search_controller | `app/javascript/controllers/` | Autocomplete pattern with autofill established |
| **Jobs** | ApplicationJob (empty base) | `app/jobs/` | Solid Queue configured, no domain jobs yet |
| **Active Storage** | Configured for local disk | `config/storage.yml` | Ready for use, direct uploads supported |

### Architecture Patterns

- **Dominant patterns**:
  - MVC with thin controllers, service objects for complex logic
  - Result objects for service outcomes (success/error pattern)
  - Turbo Frames for partial page updates
  - Stimulus controllers for JavaScript behavior
  - Autocomplete via stimulus-autocomplete library

- **Naming conventions**:
  - Services: Action-oriented (`DrugSearchService`, `OutOfRangeCalculator`)
  - Jobs: Descriptive + Job suffix (`ApplicationJob`)
  - Controllers: Standard Rails (`BiologyReportsController`)

- **Dependency direction**:
  - Controllers -> Services -> Models
  - Services return Result objects, not raise exceptions for expected failures

- **Testing approach**:
  - Minitest with fixtures
  - WebMock for HTTP stubbing
  - Test files mirror app structure

### Integration Surfaces

- **Data models/schemas**:
  - Prescription: `user_id`, `prescribed_date`, `doctor_name`, `notes` (no document attachment)
  - BiologyReport: `user_id`, `test_date`, `lab_name`, `notes`, `document` (attachment)
  - Drug: `name`, `rxcui`, `active_ingredients`
  - Biomarker: `name`, `code`, `unit`, `ref_min`, `ref_max`

- **API clients**:
  - DrugSearchService uses RxNorm API (Net::HTTP pattern)
  - No LLM clients exist yet (ruby_llm gem not installed)

- **Auth mechanisms**:
  - Session-based auth via Authentication concern
  - `Current.user` for request-scoped access
  - All controllers require auth by default

## Requirements Feasibility Analysis

### Technical Needs (from Requirements)

| Requirement | Technical Need | Category | Complexity |
|-------------|----------------|----------|------------|
| R1: Document Capture | File input with camera, Active Storage direct upload, progress indicator | UI / Data | Moderate |
| R2: Document Type Selection | Document type enum/selection, conditional routing | UI / Logic | Simple |
| R3: Prescription Data Extraction | PrescriptionScanner service, Claude Vision API, JSON parsing | API / Service | Complex |
| R4: Biology Report Extraction | BiologyReportScanner service, Claude Vision API, biomarker matching | API / Service | Complex |
| R5: Extraction Review | Editable form pre-populated from AI, confidence indicators | UI / Logic | Moderate |
| R6: Scan Flow UX | Turbo Frames for multi-step flow, Stimulus controller for camera | UI | Moderate |
| R7: AI Service Architecture | Scanner services with ruby_llm, error hierarchy, JSON schemas | Service | Moderate |
| R8: Error Handling | Image quality detection, API error handling, user feedback | Logic / UI | Moderate |
| R9: Security & Privacy | HTTPS, user-scoped data, no PII in logs | Infrastructure | Simple |
| R10: Background Processing | Solid Queue job, status tracking, Turbo Stream notifications | Job / UI | Moderate |

### Gap Analysis

| Requirement | Gap Type | Description | Impact |
|-------------|----------|-------------|--------|
| R1.5, R1.6 | Missing | Active Storage direct upload JS not configured, no progress indicator | Medium |
| R1.8, R1.9 | Missing | No file size validation (10MB limit) in DocumentValidator | Low |
| R2 | Missing | No document type concept exists in current models | Medium |
| R3, R4 | Missing | ruby_llm gem not in Gemfile, no scanner services exist | High |
| R3.7, R4.5 | Constraint | Drug.search_by_name and Biomarker.search exist but need fuzzy matching for AI output | Medium |
| R5.4 | Existing | Autocomplete controllers exist and can be reused | Low |
| R5.5 | Constraint | Prescription model lacks `has_one_attached :document` | Low |
| R6.1-6.3 | Missing | No scan flow views or Stimulus camera controller | High |
| R7.3 | Missing | ruby_llm gem integration, LlmClientFactory pattern documented but not implemented | High |
| R8.3 | Unknown | Need to research Claude Vision error response formats | Medium |
| R10.2-10.5 | Missing | No background extraction job, no status field on models | High |

**Gap Types Legend**:
- **Missing**: Capability does not exist in current codebase
- **Unknown**: Requires further research to determine feasibility
- **Constraint**: Existing architecture limits implementation options
- **Existing**: Already available, can be reused

## Implementation Approach Options

### Option A: Extend Existing Components

**When to consider**: Minimal changes, fastest initial implementation

**Files/Modules to Extend**:

| File | Change Type | Impact Assessment |
|------|-------------|-------------------|
| `app/models/prescription.rb` | Add `has_one_attached :scanned_document` | Low - adds attachment support |
| `app/validators/document_validator.rb` | Add HEIC support, 10MB size limit | Low - extend existing |
| `app/controllers/prescriptions_controller.rb` | Add `scan` action | Medium - adds new flow entry point |
| `app/controllers/biology_reports_controller.rb` | Add `scan` action | Medium - adds new flow entry point |
| `app/views/prescriptions/_form.html.erb` | Add camera capture | Medium - significant view changes |

**Trade-offs**:
- Minimal new files, faster initial development
- Leverages existing patterns and infrastructure
- Risk of bloating existing controllers with scan flow logic
- Extraction logic would need to live somewhere (still need services)
- May complicate existing CRUD flows with scanning concerns

### Option B: Create New Components

**When to consider**: Clean separation, feature has distinct lifecycle

**New Components Required**:

| Component | Responsibility | Integration Points |
|-----------|----------------|-------------------|
| `DocumentScansController` | Orchestrate scan flow (capture -> type -> extract -> review -> confirm) | Routes, views, creates Prescription/BiologyReport |
| `PrescriptionScannerService` | AI extraction for prescriptions via Claude Vision | ruby_llm, Drug model |
| `BiologyReportScannerService` | AI extraction for biology reports via Claude Vision | ruby_llm, Biomarker model |
| `DocumentExtractionJob` | Background processing for long extractions | Solid Queue, scanner services |
| `ScanSession` model (optional) | Persist scan state for background processing | ActiveRecord, polymorphic to Prescription/BiologyReport |
| `camera_controller.js` | Camera capture, preview, upload handling | Stimulus, Active Storage |
| `scan_review_controller.js` | Form autofill from extraction, confidence display | Stimulus |

**Trade-offs**:
- Clean separation of concerns
- Easier to test scanning in isolation
- Clear feature boundary for future enhancements
- More files to navigate initially
- Requires careful interface design between scan and existing CRUD

### Option C: Hybrid Approach (Recommended)

**When to consider**: Complex feature requiring both extension and new creation

**Combination Strategy**:

| Part | Approach | Rationale |
|------|----------|-----------|
| Models (Prescription attachment) | Extend | Simple addition, maintains existing model structure |
| DocumentValidator | Extend | Add HEIC and size validation to existing validator |
| Scanner Services | Create New | Distinct AI logic, testable in isolation |
| Background Job | Create New | New capability, doesn't fit existing patterns |
| Scan Flow Controller | Create New | Distinct multi-step flow, separate from CRUD |
| Stimulus Controllers | Create New | Camera and review have unique behaviors |
| Routes | Extend | Add scan routes alongside existing resources |

**Phased Implementation**:

1. **Phase 1: Foundation**
   - Add ruby_llm gem to Gemfile
   - Create LlmClientFactory and base scanner services
   - Extend Prescription with document attachment
   - Extend DocumentValidator with HEIC/size validation

2. **Phase 2: Core Extraction**
   - Create PrescriptionScannerService with Claude Vision integration
   - Create BiologyReportScannerService
   - Implement drug/biomarker fuzzy matching

3. **Phase 3: UI Flow**
   - Create DocumentScansController with scan flow actions
   - Create camera_controller.js for capture/preview
   - Create scan_review_controller.js for form handling
   - Build Turbo Frame views for step transitions

4. **Phase 4: Background & Polish**
   - Create DocumentExtractionJob for long-running extractions
   - Add extraction status tracking
   - Implement Turbo Stream notifications
   - Add confidence indicators

**Risk mitigation**:
- Incremental rollout: each phase is independently deployable
- Feature flag potential: can gate entire scan feature
- Rollback: new components can be removed without affecting existing CRUD

**Trade-offs**:
- Balanced approach for complex features
- Allows iterative refinement and early user feedback
- More complex planning required
- Potential for inconsistency if phases not coordinated

## Effort and Risk Assessment

### Effort Estimate

| Option | Effort | Justification |
|--------|--------|---------------|
| A | M (3-7 days) | Extends existing components but still needs services; scanning logic cramped |
| B | L (1-2 weeks) | Clean implementation but more boilerplate; new controller/views from scratch |
| C | L (1-2 weeks) | Phased approach spreads effort; foundation exists for each phase |

**Effort Scale**:
- **S** (1-3 days): Existing patterns, minimal dependencies, straightforward integration
- **M** (3-7 days): Some new patterns/integrations, moderate complexity
- **L** (1-2 weeks): Significant functionality, multiple integrations or workflows
- **XL** (2+ weeks): Architectural changes, unfamiliar tech, broad impact

### Risk Assessment

| Option | Risk | Justification |
|--------|------|---------------|
| A | Medium | Extends known patterns but may create maintenance issues as scanning grows |
| B | Medium | Clean design but more surface area for bugs; integration testing critical |
| C | Medium | Phased reduces risk; each phase can be validated before proceeding |

**Risk Factors**:
- **High**: Unknown tech, complex integrations, architectural shifts, unclear perf/security path
- **Medium**: New patterns with guidance, manageable integrations, known perf solutions
- **Low**: Extend established patterns, familiar tech, clear scope, minimal integration

### Specific Risks Identified

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Claude Vision API response format changes | Low | Medium | Define explicit JSON schema in prompts; handle parsing failures gracefully |
| Drug/biomarker fuzzy matching accuracy | Medium | Medium | Implement confidence scores; always require user confirmation |
| Mobile camera access issues on iOS PWA | Medium | High | Use simple file input with `capture` attribute; test on real devices early |
| Large images causing slow extraction | Medium | Medium | Implement image compression; offer background processing option |
| Rate limiting from Claude API | Low | Medium | Implement retry with backoff; queue jobs to spread load |

## Recommendations for Design Phase

### Preferred Approach

**Recommended Option**: C (Hybrid Approach)

**Rationale**:
- Balances clean architecture with pragmatic reuse of existing patterns
- Phased implementation reduces risk and enables early validation
- Dedicated scanner services align with steering guidance for LLM integration
- New scan flow controller keeps CRUD controllers focused on their responsibility
- Existing Turbo/Stimulus patterns provide solid foundation for UI flow

### Key Decisions Required

1. **Scan Session Persistence**: Should scan state be persisted to database (new model) or kept in session/temporary storage?
   - Affects background processing capability
   - Recommendation: Use database model for robustness

2. **Extraction Status Location**: Add status field to Prescription/BiologyReport models or create separate ScanSession model?
   - Trade-off: Model simplicity vs. feature encapsulation
   - Recommendation: Add to existing models for simplicity

3. **Image Optimization**: Compress images before sending to Claude or send originals?
   - Trade-off: Speed/cost vs. extraction accuracy
   - Recommendation: Compress to max 2048px dimension, preserve aspect ratio

4. **Camera Implementation**: Use simple file input with capture attribute or build custom getUserMedia solution?
   - Trade-off: Simplicity vs. control
   - Recommendation: Start with simple file input; enhance later if needed

### Research Items to Carry Forward

| Item | Priority | Reason |
|------|----------|--------|
| ruby_llm gem vision API exact usage with Active Storage blobs | High | Core integration point; need to understand blob-to-base64 pattern |
| Claude Vision error response formats | High | Required for error handling implementation |
| Active Storage direct upload JavaScript patterns | Medium | For progress indicator implementation |
| Fuzzy matching algorithm for drug/biomarker names | Medium | AI may return variations of database names |
| Image compression strategies in Ruby | Medium | Balance quality vs. API performance |
| Turbo Stream patterns for background job completion | Medium | For real-time status updates |

## Out of Scope

Items explicitly deferred to design phase:

- Detailed JSON schema for Claude Vision prompts (requires iteration)
- Exact database migration structure for extraction status
- CSS styling for scan flow UI
- Internationalization of extraction prompts
- Performance benchmarks for Claude Vision response times
- Integration test strategy for AI services
- Hotwire Native bridge component implementation (future enhancement)
