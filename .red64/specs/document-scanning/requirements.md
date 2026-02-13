# Requirements Document

## Introduction

This document defines the requirements for implementing AI-powered document scanning capabilities in Avicen. The feature enables users to capture images of prescriptions and biology reports, automatically extract structured data using Claude Vision API, and confirm extracted information before saving. This corresponds to Phase 4 of the Avicen implementation plan.

The document scanning feature serves two primary user personas:
- **John**: Self-managing thyroid condition, needs to digitize prescriptions and lab reports
- **Jane**: Caregiver for her father with microvascularite, needs to quickly input medical documents

## Requirements

### Requirement 1: Document Capture

**Objective:** As a user, I want to capture or upload images of medical documents, so that I can extract data without manual entry.

#### Acceptance Criteria

1. When user opens the document scanning interface, the Document Scanning Service shall display options for camera capture and file upload.
2. When user selects camera capture on a mobile device, the Document Scanning Service shall open the device camera with the rear-facing camera selected by default.
3. When user selects file upload, the Document Scanning Service shall accept image files in JPEG, PNG, HEIC, and PDF formats.
4. When user captures or uploads an image, the Document Scanning Service shall display a preview of the captured image before processing.
5. The Document Scanning Service shall upload captured images directly to Active Storage using Rails direct upload mechanism.
6. While image is being uploaded, the Document Scanning Service shall display upload progress indicator.
7. If image upload fails, then the Document Scanning Service shall display an error message and allow retry.
8. The Document Scanning Service shall limit maximum file size to 10MB per image.
9. If uploaded file exceeds size limit, then the Document Scanning Service shall display a clear error message indicating the size constraint.

### Requirement 2: Document Type Selection

**Objective:** As a user, I want to specify what type of document I am scanning, so that the system can apply appropriate extraction logic.

#### Acceptance Criteria

1. When user initiates document scanning, the Document Scanning Service shall prompt user to select document type before or after image capture.
2. The Document Scanning Service shall support two document types: Prescription and Biology Report.
3. When user selects Prescription type, the Document Scanning Service shall use prescription-specific extraction prompts for AI processing.
4. When user selects Biology Report type, the Document Scanning Service shall use biology report-specific extraction prompts for AI processing.
5. The Document Scanning Service shall allow user to change document type before submitting for extraction.

### Requirement 3: Prescription Data Extraction

**Objective:** As a user, I want the system to automatically extract prescription details from scanned images, so that I can add medications with minimal manual input.

#### Acceptance Criteria

1. When user submits a prescription image for extraction, the Document Scanning Service shall send the image to Claude Vision API for processing.
2. When processing prescription images, the Document Scanning Service shall extract the following data: drug names, dosages, frequencies, duration, quantity, prescribing doctor name, and prescription date.
3. While AI extraction is in progress, the Document Scanning Service shall display a processing indicator with estimated wait time.
4. When extraction completes successfully, the Document Scanning Service shall return structured JSON data containing all extracted fields.
5. When multiple medications are present on a single prescription, the Document Scanning Service shall extract and return all medications as separate entries.
6. If drug name cannot be confidently identified, then the Document Scanning Service shall flag the field as requiring user verification.
7. The Document Scanning Service shall attempt to match extracted drug names against the local Drug database to suggest standardized entries.
8. When drug match is found in database, the Document Scanning Service shall populate associated metadata (active ingredients, contraindications, RxCUI).
9. If extraction fails due to image quality issues, then the Document Scanning Service shall inform user and suggest retaking the image with better lighting or focus.

### Requirement 4: Biology Report Data Extraction

**Objective:** As a user, I want the system to automatically extract test results from scanned lab reports, so that I can track my biomarkers without tedious data entry.

#### Acceptance Criteria

1. When user submits a biology report image for extraction, the Document Scanning Service shall send the image to Claude Vision API for processing.
2. When processing biology report images, the Document Scanning Service shall extract: test date, lab name, and individual test results including biomarker names, values, units, and reference ranges.
3. While AI extraction is in progress, the Document Scanning Service shall display a processing indicator.
4. When extraction completes successfully, the Document Scanning Service shall return structured JSON data containing all extracted test results.
5. The Document Scanning Service shall attempt to match extracted biomarker names against the local Biomarker database.
6. When biomarker match is found, the Document Scanning Service shall use standardized biomarker name and populate default reference ranges if not extracted.
7. When extracted values fall outside reference ranges, the Document Scanning Service shall automatically flag them as out-of-range.
8. If a test result value or unit cannot be confidently identified, then the Document Scanning Service shall flag the field as requiring user verification.
9. If extraction fails due to image quality or unsupported report format, then the Document Scanning Service shall inform user with specific guidance.

### Requirement 5: Extraction Review and Confirmation

**Objective:** As a user, I want to review and edit extracted data before saving, so that I can correct any AI extraction errors.

#### Acceptance Criteria

1. When AI extraction completes, the Document Scanning Service shall display all extracted data in an editable form.
2. The Document Scanning Service shall visually highlight fields that the AI flagged as low-confidence or requiring verification.
3. When user edits any extracted field, the Document Scanning Service shall update the corresponding form value.
4. The Document Scanning Service shall provide autocomplete suggestions for drug names and biomarker names when user edits those fields.
5. When user confirms extracted prescription data, the Document Scanning Service shall create a new Prescription record with associated Medication and Schedule records.
6. When user confirms extracted biology report data, the Document Scanning Service shall create a new BiologyReport record with associated TestResult records.
7. If user cancels the review process, then the Document Scanning Service shall discard extracted data and return to scanning interface.
8. The Document Scanning Service shall preserve the original scanned image and attach it to the created record using Active Storage.
9. When user confirms and saves, the Document Scanning Service shall display success confirmation with link to view created record.

### Requirement 6: Scan Flow User Experience

**Objective:** As a user, I want a smooth, guided scanning experience, so that document digitization feels effortless.

#### Acceptance Criteria

1. The Document Scanning Service shall implement the scan flow using Turbo Frames for seamless step transitions without full page reloads.
2. When transitioning between scan flow steps (capture, processing, review, confirm), the Document Scanning Service shall update only the relevant page section.
3. The Document Scanning Service shall provide a Stimulus controller for camera capture preview functionality.
4. The Document Scanning Service shall provide visual confidence indicators for each extracted field based on AI certainty scores.
5. While any async operation is in progress, the Document Scanning Service shall disable form submission to prevent duplicate requests.
6. If network connection is lost during extraction, then the Document Scanning Service shall display error and offer retry option.
7. The Document Scanning Service shall allow user to navigate back to previous steps without losing current progress.
8. When scan flow completes successfully, the Document Scanning Service shall offer option to scan another document.

### Requirement 7: AI Service Integration

**Objective:** As a developer, I want a clean service architecture for AI document processing, so that the extraction logic is maintainable and testable.

#### Acceptance Criteria

1. The Document Scanning Service shall implement AI extraction via a dedicated PrescriptionScanner service class.
2. The Document Scanning Service shall implement AI extraction via a dedicated BiologyReportScanner service class.
3. The PrescriptionScanner and BiologyReportScanner services shall use the ruby_llm gem as per the project's LLM integration patterns.
4. The scanner services shall use Claude model with vision capabilities for image analysis.
5. The scanner services shall define explicit JSON schemas in prompts to ensure structured output format.
6. If Claude API returns rate limit error, then the scanner services shall raise a typed RateLimitError for proper handling.
7. If Claude API returns authentication error, then the scanner services shall raise a typed AuthenticationError.
8. The scanner services shall truncate image descriptions to fit within token limits as per project LLM patterns.
9. The scanner services shall parse AI responses and handle potential JSON extraction from markdown code fences.
10. The scanner services shall be testable with mocked LLM responses as per project testing patterns.

### Requirement 8: Error Handling and Edge Cases

**Objective:** As a user, I want clear feedback when things go wrong, so that I can take corrective action.

#### Acceptance Criteria

1. If scanned image contains no recognizable medical document, then the Document Scanning Service shall inform user and suggest verifying document type selection.
2. If scanned image is too blurry or low resolution for reliable extraction, then the Document Scanning Service shall provide specific guidance for retaking the image.
3. If Claude API is temporarily unavailable, then the Document Scanning Service shall display a user-friendly error and offer to save the image for later processing.
4. If extracted drug name does not match any known drug in database, then the Document Scanning Service shall allow user to proceed with custom drug entry.
5. If extracted biomarker name does not match any known biomarker in database, then the Document Scanning Service shall allow user to proceed with custom biomarker entry.
6. The Document Scanning Service shall log extraction failures with sanitized details for troubleshooting while excluding sensitive medical information from logs.
7. While user is reviewing extracted data, the Document Scanning Service shall preserve state even if user navigates away and returns.

### Requirement 9: Security and Privacy

**Objective:** As a user, I want my medical documents handled securely, so that my sensitive health information remains private.

#### Acceptance Criteria

1. The Document Scanning Service shall transmit all images over HTTPS only.
2. The Document Scanning Service shall scope all document operations to the authenticated user's account.
3. The Document Scanning Service shall not log extracted medical content in plain text.
4. When images are sent to Claude API, the Document Scanning Service shall not include user identifying information in prompts.
5. The Document Scanning Service shall store scanned images in Active Storage with user-scoped access.
6. If user deletes a prescription or biology report record, then the Document Scanning Service shall also delete the associated scanned image attachment.

### Requirement 10: Background Processing Option

**Objective:** As a user, I want the option to process documents in the background, so that I can continue using the app while extraction happens.

#### Acceptance Criteria

1. Where document extraction takes longer than 5 seconds, the Document Scanning Service shall offer option to continue processing in background.
2. When user selects background processing, the Document Scanning Service shall enqueue extraction job to Solid Queue.
3. While background extraction is pending, the Document Scanning Service shall show document status as "Processing" in relevant lists.
4. When background extraction completes, the Document Scanning Service shall update document status and notify user via Turbo Stream if they are on a related page.
5. If background extraction fails, then the Document Scanning Service shall mark document as "Extraction Failed" and preserve original image for retry.
6. The Document Scanning Service shall allow user to manually retry failed background extractions.
