# Implementation Plan

## Overview

This document outlines the implementation tasks for the biology reports feature. Tasks are organized into major phases with sub-tasks sized for 1-3 hours each. Tasks marked with `(P)` can be executed in parallel when safe to do so.

---

## Tasks

- [x] 1. Create database schema and seed biomarker catalog
- [x] 1.1 (P) Generate migrations for biomarkers, biology_reports, and test_results tables
  - Create biomarkers table with name, code, unit, ref_min, ref_max, timestamps
  - Add indexes on biomarkers.code (unique) and biomarkers.name for search performance
  - Create biology_reports table with user_id, test_date, lab_name, notes, timestamps
  - Add foreign key constraint from biology_reports.user_id to users.id with cascade delete
  - Add composite index on biology_reports (user_id, test_date) for filtering queries
  - Create test_results table with biology_report_id, biomarker_id, value, unit, ref_min, ref_max, out_of_range, timestamps
  - Add foreign key from test_results.biology_report_id to biology_reports.id with cascade delete
  - Add foreign key from test_results.biomarker_id to biomarkers.id with restrict delete
  - Add indexes on test_results (biology_report_id, biomarker_id, out_of_range)
  - _Requirements: 7.1, 7.2, 7.5_

- [x] 1.2 (P) Create seed data for common biomarkers
  - Seed 20-30 common biomarkers covering CBC (hemoglobin, WBC, platelets), metabolic panel (glucose, creatinine, sodium, potassium), lipid panel (total cholesterol, LDL, HDL, triglycerides), thyroid (TSH, Free T4), vitamins (D, B12), liver function (ALT, AST), and inflammation (CRP)
  - Include LOINC-compatible codes, default units, and typical reference ranges for each biomarker
  - Use db/seeds.rb or dedicated biomarker seed file with idempotent logic
  - _Requirements: 1.1_

- [x] 2. Implement core models with associations and validations
- [ ] 2.1 (P) Create Biomarker model
  - Define associations: has_many :test_results
  - Add validations for presence of name, code, unit, ref_min, ref_max
  - Add uniqueness validation on code (case-insensitive)
  - Add numericality validations for ref_min and ref_max
  - Create search scope for autocomplete by name or code (case-insensitive LIKE query)
  - Implement class method to return top 10 matches for autocomplete
  - _Requirements: 1.1, 1.2, 7.2_

- [ ] 2.2 Create BiologyReport model with Active Storage integration
  - Define associations: belongs_to :user, has_many :test_results with dependent: :destroy
  - Add validations for presence of test_date, user_id
  - Configure has_one_attached :document for PDF/image attachment
  - Add custom validator for document content type (PDF, JPEG, PNG only)
  - Create scope ordered by test_date descending
  - Create scope for filtering by date range
  - Create scope for filtering by laboratory name (case-insensitive partial match)
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 4.1, 4.2, 4.5, 7.1, 7.5_

- [ ] 2.3 Create TestResult model with out-of-range calculation
  - Define associations: belongs_to :biology_report, belongs_to :biomarker
  - Add validations for presence of biomarker_id, value, unit
  - Add numericality validation for value
  - Add before_save callback to invoke OutOfRangeCalculator service
  - Store calculated out_of_range boolean flag
  - Create scope to filter results by out_of_range status
  - Create scope to fetch results grouped by biomarker for trend queries
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 7.2, 7.3, 7.4, 7.5_

- [ ] 3. Implement service objects for business logic
- [ ] 3.1 (P) Create OutOfRangeCalculator service
  - Implement class method call(value:, ref_min:, ref_max:) returning boolean or nil
  - Return true when value is below ref_min or above ref_max
  - Return false when value is within range
  - Return nil when ref_min or ref_max is nil
  - Handle edge case where value equals boundary (considered in range)
  - _Requirements: 3.4, 3.6_

- [ ] 3.2 (P) Create DocumentValidator custom validator
  - Implement ActiveModel::Validator for BiologyReport document attachment
  - Define ALLOWED_TYPES constant with application/pdf, image/jpeg, image/png
  - Check attached document content_type against allowed list
  - Add validation error to record.errors[:document] when type invalid
  - Handle case when document is not attached (no validation error)
  - _Requirements: 4.2, 4.5_

- [ ] 4. Build BiologyReportsController with CRUD and filtering
- [ ] 4.1 Implement RESTful controller actions
  - Create index action scoped through Current.user.biology_reports with default ordering
  - Implement show action with user-scoped find to prevent unauthorized access
  - Create new action rendering empty form
  - Implement create action with strong parameters, save, and redirect on success
  - Implement edit action loading existing report with user scoping
  - Create update action handling metadata changes and document upload
  - Implement destroy action with cascade delete of test results
  - Handle validation errors with status: :unprocessable_entity
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 4.2 Add filtering capabilities with Turbo Frame support
  - Accept date_from, date_to, lab_name query parameters in index action
  - Apply filters using BiologyReport scopes
  - Return Turbo Frame partial for filtered results when turbo_frame request detected
  - Return full HTML page for regular requests
  - Preserve filter state in URL query parameters
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 4.3 (P) Create views for biology reports (index, show, form)
  - Build index view with Turbo Frame for report list
  - Display reports in reverse chronological order with test date, lab name, notes
  - Add filter form for date range and lab name with Turbo Frame target
  - Create show view displaying report metadata and associated test results
  - Highlight out-of-range test results with distinct visual treatment (color and icon)
  - Display attached document with link to view or download
  - Build _form partial with fields for test_date, lab_name, notes, document upload
  - Include form validation error display
  - _Requirements: 2.1, 2.3, 2.4, 4.3, 4.4, 5.5_

- [ ] 5. Build TestResultsController with nested CRUD
- [ ] 5.1 Implement nested controller under biology_reports
  - Configure nested routes: /biology_reports/:biology_report_id/test_results
  - Add before_action to load parent biology_report with user scoping
  - Implement new action with biomarker_id query parameter for auto-fill
  - Fetch biomarker to pre-populate default unit and reference ranges in form
  - Create create action with strong parameters, Turbo Stream response
  - Implement edit action loading existing test result
  - Create update action with Turbo Stream partial replacement
  - Implement destroy action with Turbo Stream removal
  - _Requirements: 3.1, 3.2, 3.3, 3.5, 3.6_

- [ ] 5.2 (P) Create views for test results (nested forms, list partial)
  - Build _form partial with fields for biomarker selection, value, unit, ref_min, ref_max
  - Pre-populate unit and reference ranges from biomarker catalog when biomarker_id present
  - Allow user to override auto-filled ref_min and ref_max values
  - Create _test_result partial displaying biomarker name, value, unit, reference range, out-of-range flag
  - Build Turbo Stream templates for create, update, destroy actions
  - Update test result list without full page reload using turbo_stream.replace
  - _Requirements: 1.3, 1.4, 3.1, 3.2, 3.3, 3.5_

- [ ] 6. Implement biomarker search with autocomplete
- [ ] 6.1 (P) Create BiomarkerSearchController for autocomplete endpoint
  - Implement search action accepting query parameter q
  - Return empty list when query length less than 2 characters
  - Query Biomarker model with case-insensitive LIKE on name and code
  - Limit results to top 10 matches
  - Render HTML fragments (li elements with role="option") for stimulus-autocomplete
  - Include data attributes for biomarker ID, name, code, default unit, ref_min, ref_max
  - _Requirements: 1.2_

- [ ] 6.2 Create biomarker-search Stimulus controller
  - Extend stimulus-autocomplete controller class
  - Configure with /biomarkers/search endpoint
  - Set minimum query length to 2 characters
  - Handle autocomplete selection event
  - Populate hidden biomarker_id field and visible biomarker name display
  - Auto-fill unit, ref_min, ref_max fields from biomarker data attributes
  - Follow existing drug-search Stimulus controller pattern
  - _Requirements: 1.2, 1.3_

- [ ] 7. Integrate Chart.js for biomarker trend visualization
- [ ] 7.1 (P) Pin Chart.js and annotation plugin via importmap
  - Add Chart.js 4.4.1 to config/importmap.rb with CDN URL
  - Pin chartjs-plugin-annotation 3.x for reference range bands
  - Verify importmap pins resolve correctly
  - _Requirements: 5.1, 5.2_

- [ ] 7.2 Create BiomarkerTrendsController for chart data
  - Implement show action accepting biomarker_id parameter
  - Query TestResults for Current.user and specified biomarker, ordered by test_date ascending
  - Format data as JSON with labels (test dates), datasets (values), and annotations (reference range bands)
  - Include reference range min/max for annotation plugin configuration
  - Return 404 when biomarker not found or no data exists for user
  - When fewer than 2 data points, set flag to render table instead of chart
  - Pass chart data to view via instance variable
  - _Requirements: 5.1, 5.2, 5.4_

- [ ] 7.3 Create biomarker-chart Stimulus controller
  - Import Chart.js and chartjs-plugin-annotation
  - Register annotation plugin with Chart.register
  - Parse chart data from data-chart-data-value attribute (JSON)
  - Initialize Chart.js line chart with canvas target
  - Configure annotation plugin to display reference range as shaded box region
  - Make data points clickable, navigating to corresponding biology_report_path
  - Implement disconnect() to destroy chart and prevent memory leaks
  - Handle missing data gracefully by checking data point count
  - _Requirements: 5.1, 5.2, 5.4_

- [ ] 7.4 (P) Create biomarker trends view
  - Build view displaying biomarker name and trend chart canvas element
  - Attach biomarker-chart Stimulus controller with data attributes
  - Render table view when fewer than 2 data points available
  - Include navigation links to return to report list
  - Display message when insufficient data for trend chart
  - _Requirements: 5.1, 5.3_

- [ ] 8. Implement biomarker index and filtering UI
- [ ] 8.1 (P) Create biomarker index view showing recorded biomarkers
  - Query distinct biomarkers across Current.user's test results
  - Display biomarker list as clickable cards or links
  - Link each biomarker to its trend visualization page
  - Show count of test results per biomarker
  - Order biomarkers alphabetically by name
  - _Requirements: 6.4_

- [ ] 8.2 Create filter-form Stimulus controller for Turbo Frame filtering
  - Listen to form input change events (date range, lab name)
  - Submit form automatically via Turbo Frame on input change
  - Debounce input events to prevent rapid successive requests
  - Target turbo-frame#biology_reports_list for partial updates
  - Preserve filter state in URL query parameters
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 9. Add navigation and routes for biology reports feature
- [ ] 9.1 (P) Configure routes for biology reports and nested resources
  - Add resources :biology_reports with standard REST routes
  - Nest resources :test_results under biology_reports
  - Add custom route for biomarker search: get 'biomarkers/search'
  - Add custom route for biomarker trends: get 'biomarker_trends/:biomarker_id'
  - Add custom route for biomarker index: get 'biomarkers'
  - _Requirements: 2.1, 3.1, 5.1, 6.4_

- [ ] 9.2 (P) Add Biology Reports link to application navigation
  - Update shared navbar partial with link to biology_reports_path
  - Position link appropriately in authenticated user menu
  - _Requirements: 2.1_

- [ ] 10. Write comprehensive test coverage
- [ ] 10.1 Create model tests for BiologyReport, TestResult, Biomarker
  - Test BiologyReport associations, validations, scopes, user scoping, cascade delete
  - Test TestResult associations, validations, out-of-range flag calculation, numeric validation
  - Test Biomarker validations, uniqueness, search scopes
  - Test DocumentValidator with valid and invalid file types
  - _Requirements: 1.1, 2.1, 2.6, 3.2, 3.4, 3.6, 4.2, 4.5, 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 10.2 Create service tests for OutOfRangeCalculator
  - Test in-range values return false
  - Test out-of-range values (below min, above max) return true
  - Test nil reference ranges return nil flag
  - Test boundary conditions (value equals min or max) treated as in range
  - _Requirements: 3.4, 3.6_

- [ ] 10.3 Create controller tests for BiologyReportsController
  - Test index action with user scoping and filtering by date/lab
  - Test show action with user scoping, 404 for unauthorized access
  - Test create action with valid and invalid parameters
  - Test update action with metadata changes and document upload
  - Test destroy action with cascade delete verification
  - Test Turbo Frame responses for filtered index
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 4.1, 4.3, 4.4, 6.1, 6.2, 6.3_

- [ ] 10.4 Create controller tests for TestResultsController
  - Test nested routes and parent biology_report scoping
  - Test create action with auto-filled reference ranges
  - Test update action with Turbo Stream responses
  - Test destroy action with Turbo Stream removal
  - Test user scoping prevents access to other users' test results
  - _Requirements: 3.1, 3.2, 3.3, 3.5, 3.6_

- [ ] 10.5 Create controller tests for BiomarkerSearchController
  - Test search with valid query returns HTML fragments
  - Test search with short query (less than 2 chars) returns empty list
  - Test search matches biomarker name and code
  - Test result limit to 10 matches
  - _Requirements: 1.2_

- [ ] 10.6 Create controller tests for BiomarkerTrendsController
  - Test show action with valid biomarker returns chart data JSON
  - Test show action with insufficient data renders table view
  - Test user scoping returns only Current.user's test results
  - Test 404 response when biomarker not found
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ] 10.7 Create system tests for end-to-end flows
  - Test create biology report, add test results, view report detail, verify out-of-range flagging
  - Test upload document, view document, delete document
  - Test biomarker autocomplete search, select biomarker, verify auto-filled ranges
  - Test view biomarker trend chart, click data point, navigate to report
  - Test filter biology reports by date range and lab name with Turbo Frame updates
  - _Requirements: 1.2, 1.3, 2.1, 2.5, 3.4, 4.3, 4.4, 5.4, 6.1, 6.2, 6.3_

- [ ]* 10.8 Create baseline rendering tests for UI components
  - Test biology report index page renders correctly
  - Test biology report show page renders with test results
  - Test biomarker trend chart canvas element present
  - Test filter form renders with date and lab inputs
  - _Requirements: 2.3, 5.1, 6.1_

---

## Summary

- **Total major tasks**: 10
- **Total sub-tasks**: 29
- **Parallel-capable tasks**: 13 (marked with `(P)`)
- **Optional test tasks**: 1 (marked with `*`)

All 7 requirements are covered across the implementation tasks. Tasks are sized for 1-3 hours each and follow Rails 8 conventions with Hotwire patterns. The feature builds on existing authentication, user scoping, Turbo Frames/Streams, Active Storage, and service object patterns.
