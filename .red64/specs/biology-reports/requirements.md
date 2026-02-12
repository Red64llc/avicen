# Requirements Document

## Introduction

This document defines the requirements for **Phase 3: Biology Reports** of the Avicen personal health management application. The goal is to enable authenticated users to store, manage, and visualize biology/lab test results over time. Users should be able to manually enter lab report data, attach original documents, see out-of-range values flagged automatically, and view biomarker trends through interactive charts. The feature builds on the existing authentication, user profile, and medication management foundation (Phases 0-2).

## Requirements

### Requirement 1: Biomarker Reference Data

**Objective:** As a user, I want the system to maintain a catalog of common biomarkers with default reference ranges, so that I do not have to enter reference information manually for every test result.

#### Acceptance Criteria
1. The Avicen system shall provide a Biomarker catalog containing at minimum the biomarker name, code, default unit, and typical reference range (minimum and maximum).
2. When a user searches for a biomarker during test result entry, the Avicen system shall return matching biomarkers using autocomplete based on name or code.
3. When a biomarker is selected, the Avicen system shall auto-fill the default unit and reference range values into the test result form.
4. The Avicen system shall allow the user to override auto-filled reference range values with lab-specific ranges provided on their report.

### Requirement 2: Biology Report Management

**Objective:** As a user, I want to create, view, edit, and delete biology reports associated with my account, so that I can maintain a complete history of my lab work.

#### Acceptance Criteria
1. The Avicen system shall allow an authenticated user to create a new biology report with a test date, laboratory name, and optional notes.
2. The Avicen system shall scope all biology reports to the currently authenticated user so that users can only access their own reports.
3. When a user views the biology reports list, the Avicen system shall display reports in reverse chronological order by test date.
4. The Avicen system shall allow the user to edit an existing biology report's metadata (test date, laboratory name, notes).
5. When a user deletes a biology report, the Avicen system shall remove the report and all associated test results.
6. The Avicen system shall validate that a test date is present before saving a biology report.

### Requirement 3: Test Result Entry

**Objective:** As a user, I want to enter individual test results within a biology report, so that I can record each biomarker value from my lab work.

#### Acceptance Criteria
1. The Avicen system shall allow the user to add one or more test results to a biology report, each associated with a biomarker.
2. When a user enters a test result, the Avicen system shall require a biomarker selection, a numeric value, and a unit.
3. The Avicen system shall store the reference range minimum and maximum for each test result, either auto-filled from the biomarker catalog or manually entered by the user.
4. When a test result value falls outside the stored reference range, the Avicen system shall automatically flag that result as out of range.
5. The Avicen system shall allow the user to edit or remove individual test results within a report.
6. When a test result is added or updated, the Avicen system shall recalculate the out-of-range flag based on the current value and reference range.

### Requirement 4: Document Attachment

**Objective:** As a user, I want to attach original lab report documents (PDF or image) to a biology report, so that I can keep the source document alongside my structured data.

#### Acceptance Criteria
1. The Avicen system shall allow the user to attach one document (PDF or image file) to a biology report using Active Storage.
2. When a user uploads a document, the Avicen system shall validate that the file type is an accepted format (PDF, JPEG, PNG).
3. The Avicen system shall display the attached document on the biology report detail page, with a link to view or download the original file.
4. When a user removes the attached document, the Avicen system shall delete the stored file.
5. If an invalid file type is uploaded, the Avicen system shall display a validation error and reject the upload.

### Requirement 5: Biomarker Trend Visualization

**Objective:** As a user, I want to view charts showing how a specific biomarker has changed over time, so that I can understand health trends and the impact of treatments.

#### Acceptance Criteria
1. The Avicen system shall provide a biomarker history view that displays a line chart of values for a selected biomarker across all of the user's biology reports, ordered by test date.
2. The Avicen system shall display the reference range as visual bands (shaded region or horizontal lines) on the trend chart so the user can see where values fall relative to normal.
3. When fewer than two data points exist for a biomarker, the Avicen system shall display the available data in a tabular format instead of a chart.
4. The Avicen system shall allow the user to navigate from a trend chart data point to the corresponding biology report detail page.
5. When a user views a biology report detail, the Avicen system shall visually distinguish out-of-range test results from in-range results (for example, using color or an icon).

### Requirement 6: Biology Report Search and Filtering

**Objective:** As a user, I want to search and filter my biology reports, so that I can quickly find specific reports or biomarker results.

#### Acceptance Criteria
1. The Avicen system shall allow the user to filter biology reports by date range.
2. The Avicen system shall allow the user to filter biology reports by laboratory name.
3. When a user applies filters, the Avicen system shall update the report list without a full page reload, using Turbo Frame updates.
4. The Avicen system shall provide a way for the user to view all unique biomarkers that have been recorded across their reports, serving as an index for trend visualization.

### Requirement 7: Data Integrity and Validation

**Objective:** As a developer, I want the biology report data model to enforce integrity constraints, so that stored data remains consistent and reliable.

#### Acceptance Criteria
1. The Avicen system shall enforce that each biology report belongs to exactly one user via a foreign key constraint.
2. The Avicen system shall enforce that each test result belongs to exactly one biology report and one biomarker via foreign key constraints.
3. The Avicen system shall validate that test result values are numeric.
4. If a user attempts to save a test result without a required field (biomarker, value, or unit), the Avicen system shall display a descriptive validation error.
5. When a biology report is deleted, the Avicen system shall cascade-delete all associated test results.

