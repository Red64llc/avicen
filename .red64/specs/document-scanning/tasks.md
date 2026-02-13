# Implementation Plan

## Task Format Template

Implementation tasks for AI-powered document scanning feature.

---

- [x] 1. Add ruby_llm gem and configure Claude Vision integration
  - Add `ruby_llm` gem to Gemfile and run bundle install
  - Create initializer at `config/initializers/ruby_llm.rb` with Anthropic API key from credentials
  - Configure default model for vision capabilities (Claude Sonnet)
  - Set request timeout, retry settings, and backoff configuration
  - Verify configuration loads correctly in development and test environments
  - _Requirements: 7.3, 7.4_

- [x] 2. Database migrations and model extensions
- [x] 2.1 Add extraction support to Prescription model
  - Add migration for `extraction_status` integer column with default 0 and null: false
  - Add migration for `extracted_data` jsonb column (nullable)
  - Add `has_one_attached :scanned_document` to Prescription model
  - Define `extraction_status` enum with values: manual, pending, processing, extracted, confirmed, failed
  - Add extraction prefix to enum to avoid method conflicts
  - _Requirements: 5.8, 10.3_

- [x] 2.2 (P) Add extraction support to BiologyReport model
  - Add migration for `extraction_status` integer column with default 0 and null: false
  - Add migration for `extracted_data` jsonb column (nullable)
  - BiologyReport already has document attachment (verify existing `has_one_attached :document`)
  - Define `extraction_status` enum matching Prescription model
  - _Requirements: 5.8, 10.3_

- [x] 2.3 (P) Extend DocumentValidator for scanning requirements
  - Add HEIC and HEIF content types to allowed types array
  - Add 10MB maximum file size validation
  - Create validation error messages for oversized files and invalid types
  - _Requirements: 1.3, 1.8, 1.9_

- [x] 3. Image processing service for Claude Vision optimization
- [x] 3.1 Create ImageProcessingService
  - Implement service that resizes images to max 1568px in largest dimension
  - Preserve aspect ratio during resize operation
  - Convert HEIC format to JPEG for API compatibility
  - Return ProcessedImage value object with path, width, height, and content_type
  - Use MiniMagick gem for image operations
  - Handle Active Storage blob input and tempfile output
  - _Requirements: 3.1, 4.1_

- [x] 3.2 Add ImageProcessingService tests
  - Test resize behavior for images exceeding max dimension
  - Test aspect ratio preservation
  - Test HEIC to JPEG conversion
  - Test pass-through for already-compliant images
  - Mock MiniMagick operations for unit tests
  - _Requirements: 3.1, 4.1_

- [x] 4. RubyLLM schema definitions for structured extraction
- [x] 4.1 (P) Create PrescriptionExtractionSchema
  - Define schema class extending RubyLLM::Schema
  - Add optional string fields for doctor_name and prescription_date
  - Add medications array with drug_name (required), dosage, frequency, duration, quantity (optional), and confidence (required number)
  - Schema ensures structured JSON output from Claude
  - _Requirements: 3.2, 3.4, 7.5_

- [x] 4.2 (P) Create BiologyReportExtractionSchema
  - Define schema class extending RubyLLM::Schema
  - Add optional string fields for lab_name and test_date
  - Add test_results array with biomarker_name (required), value (required), unit, reference_range (optional), and confidence (required number)
  - Schema ensures structured JSON output from Claude
  - _Requirements: 4.2, 4.4, 7.5_

- [x] 5. Prescription scanner service for AI extraction
- [x] 5.1 Create PrescriptionScannerService with error hierarchy
  - Define custom error classes: Error, ConfigurationError, AuthenticationError, RateLimitError, ExtractionError
  - Create ExtractionResult value object with success/error factory methods
  - Create ExtractedMedication data class for individual medication entries
  - Implement constructor accepting image blob and optional llm_client for testing
  - _Requirements: 7.1, 7.6, 7.7_

- [ ] 5.2 Implement prescription extraction logic
  - Build extraction prompt requesting structured medication data
  - Use ruby_llm gem with vision capabilities to process image
  - Send prompt with image to Claude API via ruby_llm
  - Parse JSON response using PrescriptionExtractionSchema
  - Handle markdown code fence wrapping in responses
  - Extract multiple medications when present on single prescription
  - _Requirements: 3.1, 3.2, 3.4, 3.5, 7.3, 7.9_

- [ ] 5.3 Add drug matching and confidence scoring
  - Query Drug model to match extracted drug names
  - Use fuzzy matching for AI-generated name variations
  - Populate matched_drug reference and associated metadata (active ingredients, RxCUI)
  - Flag fields with confidence below threshold as requiring verification
  - Return ExtractionResult with all medications and metadata
  - _Requirements: 3.6, 3.7, 3.8_

- [ ] 5.4 Add PrescriptionScannerService tests
  - Mock ruby_llm responses with sample prescription JSON
  - Test successful extraction with multiple medications
  - Test drug matching integration
  - Test low confidence field flagging
  - Test error handling for API failures (rate limit, auth, network)
  - Test JSON parsing with and without markdown fences
  - _Requirements: 7.10_

- [ ] 6. Biology report scanner service for AI extraction
- [ ] 6.1 Create BiologyReportScannerService with error hierarchy
  - Define custom error classes matching PrescriptionScannerService pattern
  - Create ExtractionResult value object for biology reports
  - Create ExtractedTestResult data class with out_of_range flag
  - Implement constructor accepting image blob and optional llm_client
  - _Requirements: 7.2, 7.6, 7.7_

- [ ] 6.2 Implement biology report extraction logic
  - Build extraction prompt requesting structured test result data
  - Use ruby_llm gem with vision capabilities to process image
  - Send prompt with image to Claude API via ruby_llm
  - Parse JSON response using BiologyReportExtractionSchema
  - Handle markdown code fence wrapping in responses
  - _Requirements: 4.1, 4.2, 4.4, 7.3, 7.9_

- [ ] 6.3 Add biomarker matching and out-of-range detection
  - Query Biomarker model to match extracted biomarker names
  - Use fuzzy matching for AI-generated name variations
  - Populate default reference ranges from matched biomarker if not extracted
  - Calculate and flag out-of-range values based on reference ranges
  - Flag fields with confidence below threshold as requiring verification
  - _Requirements: 4.5, 4.6, 4.7, 4.8_

- [ ] 6.4 Add BiologyReportScannerService tests
  - Mock ruby_llm responses with sample biology report JSON
  - Test successful extraction with multiple test results
  - Test biomarker matching integration
  - Test out-of-range calculation and flagging
  - Test low confidence field flagging
  - Test error handling for API failures
  - _Requirements: 7.10_

- [ ] 7. Document extraction background job
- [ ] 7.1 Create DocumentExtractionJob
  - Inherit from ApplicationJob with default queue
  - Accept record_type, record_id, and blob_id as perform arguments
  - Route to appropriate scanner service based on record_type
  - Update record extraction_status to processing before extraction
  - Store extraction result in extracted_data jsonb column
  - Update extraction_status to extracted on success, failed on failure
  - _Requirements: 10.2, 10.4, 10.5_

- [ ] 7.2 Configure job retry and discard behavior
  - Use retry_on for RateLimitError with polynomial backoff and max 3 attempts
  - Use discard_on for ConfigurationError (non-retryable)
  - Handle ActiveRecord::RecordNotFound gracefully (record deleted while queued)
  - Log sanitized error details for troubleshooting (no medical content)
  - _Requirements: 7.6, 7.7, 8.6, 10.5_

- [ ] 7.3 Add Turbo Stream broadcast on completion
  - Broadcast status update to user's channel when extraction completes
  - Use broadcast_replace_later_to for async notification
  - Include extraction status and link to review extracted data
  - Handle case where user is no longer on related page
  - _Requirements: 10.4_

- [ ] 7.4 Add DocumentExtractionJob tests
  - Test successful extraction flow for both record types
  - Test status transitions: pending to processing to extracted
  - Test failure handling and status update to failed
  - Test retry behavior on rate limit errors
  - Test discard behavior on configuration errors
  - _Requirements: 10.5, 10.6_

- [ ] 8. Document scans controller and routing
- [ ] 8.1 Create DocumentScansController with scan flow actions
  - Add new action for capture interface (camera/upload options)
  - Add upload action for handling direct upload completion
  - Add extract action for triggering extraction (sync or background)
  - Add review action for displaying extracted data in editable form
  - Add confirm action for creating final Prescription or BiologyReport record
  - Scope all operations to authenticated user via Current.user
  - _Requirements: 1.1, 2.1, 5.5, 5.6, 9.2_

- [ ] 8.2 Implement extraction decision logic
  - Check if extraction might take longer than 5 seconds (based on image size or heuristic)
  - Offer background processing option when threshold exceeded
  - For sync extraction: call scanner service directly and render review
  - For background extraction: enqueue DocumentExtractionJob and show processing status
  - _Requirements: 10.1, 10.2_

- [ ] 8.3 Add routes for document scanning flow
  - Add resource routes under document_scans namespace
  - Configure routes for Turbo Frame requests
  - Add nested routes for type-specific flows if needed
  - _Requirements: 6.1, 6.2_

- [ ] 8.4 Add DocumentScansController tests
  - Test authentication requirement for all actions
  - Test user scoping (cannot access other users' scans)
  - Test successful flow through capture, upload, extract, review, confirm
  - Test Turbo Frame response format
  - Test error handling for invalid inputs
  - _Requirements: 9.2, 9.5_

- [ ] 9. Camera and upload UI with Stimulus controller
- [ ] 9.1 Create camera_controller.js Stimulus controller
  - Define targets for preview, progress indicator, file input, and submit button
  - Define maxSize value with 10MB default
  - Implement state machine: idle, previewing, uploading, uploaded, error
  - Handle file selection and display preview before processing
  - Validate file size before upload and show error for oversized files
  - _Requirements: 1.4, 1.8, 1.9, 6.3_

- [ ] 9.2 Integrate Active Storage direct upload events
  - Listen for direct-upload:initialize, start, progress, error, end events
  - Update progress indicator during upload
  - Handle upload errors with user-friendly messages and retry option
  - Enable submit button only after successful upload
  - Disable form during upload to prevent duplicate requests
  - _Requirements: 1.5, 1.6, 1.7, 6.5_

- [ ] 9.3 Create scan flow views with Turbo Frames
  - Create new.html.erb with capture interface (camera button and file upload)
  - Use file input with capture="environment" for mobile camera access
  - Wrap scan flow in turbo_frame_tag for seamless step transitions
  - Show document type selection after image captured
  - Add back navigation between steps without losing progress
  - _Requirements: 1.1, 1.2, 2.1, 2.2, 2.5, 6.1, 6.2, 6.7_

- [ ] 9.4 Add processing indicator view
  - Create processing partial showing extraction in progress
  - Display estimated wait time based on document complexity
  - Offer background processing option when extraction takes long
  - Auto-refresh via Turbo when extraction completes
  - _Requirements: 3.3, 4.3, 6.5, 10.1_

- [ ] 10. Review form UI with confidence indicators
- [ ] 10.1 Create review_form_controller.js Stimulus controller
  - Define targets for form fields, confidence indicators, and submit button
  - Highlight fields flagged as low confidence (below 0.8 threshold)
  - Track which fields have been user-verified through editing
  - Mark edited fields as verified in hidden form fields
  - _Requirements: 5.2, 5.3, 6.4_

- [ ] 10.2 Create prescription review form view
  - Display all extracted medications in editable form
  - Show confidence indicators for each field visually
  - Integrate drug_search autocomplete for drug name editing
  - Allow adding/removing medications from extraction
  - Show matched drug metadata when available
  - _Requirements: 5.1, 5.4, 5.7_

- [ ] 10.3 Create biology report review form view
  - Display all extracted test results in editable form
  - Show confidence indicators for each field visually
  - Integrate biomarker_search autocomplete for biomarker name editing
  - Highlight out-of-range values with visual indicator
  - Allow adding/removing test results from extraction
  - _Requirements: 5.1, 5.4, 5.7_

- [ ] 10.4 Add confirmation and cancellation handling
  - On confirm: create Prescription/BiologyReport with associated records
  - Attach original scanned image to created record
  - Update extraction_status to confirmed
  - Show success message with link to view created record
  - On cancel: discard extracted data and return to scanning interface
  - Offer option to scan another document after completion
  - _Requirements: 5.5, 5.6, 5.7, 5.8, 5.9, 6.8_

- [ ] 11. Error handling and user feedback
- [ ] 11.1 Implement image quality error detection
  - Detect when extraction result indicates image quality issues
  - Show specific guidance for blurry images (better lighting, focus)
  - Show specific guidance when no medical document detected
  - Suggest verifying document type selection when extraction fails
  - _Requirements: 3.9, 4.9, 8.1, 8.2_

- [ ] 11.2 Implement API error handling in UI
  - Show user-friendly message when Claude API is unavailable
  - Offer to save image for later processing on API failure
  - Display retry option for transient errors
  - Handle network connection loss during extraction gracefully
  - _Requirements: 8.3, 6.6_

- [ ] 11.3 Handle unknown drug and biomarker entries
  - Allow user to proceed with custom drug entry when no match found
  - Allow user to proceed with custom biomarker entry when no match found
  - Show warning that entry is not in database
  - Still validate required fields for custom entries
  - _Requirements: 8.4, 8.5_

- [ ] 11.4 Implement state preservation for review
  - Store extraction state in session or database while user reviews
  - Preserve state if user navigates away and returns
  - Clean up stale extraction state after timeout
  - _Requirements: 8.7_

- [ ] 12. Security and privacy implementation
- [ ] 12.1 Ensure secure image transmission and storage
  - Verify all image uploads use HTTPS only (Rails default)
  - Configure Active Storage with user-scoped paths
  - Verify scanned images are accessible only to owning user
  - _Requirements: 9.1, 9.5_

- [ ] 12.2 Configure privacy-safe logging
  - Filter extracted medical content from logs
  - Add extracted_data to parameter filter list
  - Ensure Claude API prompts contain no user identifying information
  - Log extraction failures without sensitive details
  - _Requirements: 9.3, 9.4, 8.6_

- [ ] 12.3 Implement record deletion cascade
  - Configure dependent: :purge_later for scanned_document attachment
  - Verify image deleted when Prescription record deleted
  - Verify document deleted when BiologyReport record deleted
  - _Requirements: 9.6_

- [ ] 13. Integration testing and final verification
- [ ] 13.1 Add integration tests for full scan flow
  - Test prescription scan: upload to extraction to review to confirm
  - Test biology report scan: upload to extraction to review to confirm
  - Test background extraction flow with status updates
  - Test cancellation at each step of the flow
  - Mock Claude API responses for deterministic testing
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.5, 5.6_

- [ ] 13.2 Add system tests for user experience
  - Test mobile viewport camera capture interaction
  - Test file upload with progress indicator
  - Test review form editing and autocomplete
  - Test Turbo Frame transitions between steps
  - Test error message display and recovery
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.7, 6.8_

- [ ] 13.3 Verify security controls
  - Test user scoping: cannot access other users' documents
  - Test authentication requirement on all endpoints
  - Test that medical content is not logged
  - Verify HTTPS-only image transmission
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_
