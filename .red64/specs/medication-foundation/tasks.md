# Implementation Plan

- [ ] 1. Database foundation and model layer
- [x] 1.1 Create the Drug model with migration, validations, and search scope
  - Create the `drugs` table with name, rxcui, and active_ingredients columns
  - Add database indexes on name and a unique index on rxcui (allowing nulls)
  - Implement name presence validation and rxcui uniqueness validation (allow nil for manually entered drugs)
  - Add the `search_by_name` scope for LIKE-based name matching
  - Add `has_many :medications` association with `dependent: :restrict_with_error`
  - Write model tests: name validation, rxcui uniqueness, search scope, association
  - Create fixtures for drug test data
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 1.2 Create the Prescription model with migration, validations, and user association
  - Create the `prescriptions` table with user_id foreign key, doctor_name, prescribed_date, and notes
  - Add database indexes on user_id and on (user_id, prescribed_date)
  - Implement `belongs_to :user` and `has_many :medications, dependent: :destroy`
  - Add prescribed_date presence validation
  - Add the `ordered` scope for descending prescribed_date sorting
  - Add `has_many :prescriptions` association on the User model
  - Write model tests: prescribed_date validation, user association, ordered scope, cascading destroy
  - Create fixtures for prescription test data
  - _Requirements: 2.1, 2.2, 2.3, 2.6_

- [ ] 1.3 Create the Medication model with migration, validations, and associations
  - Create the `medications` table with prescription_id, drug_id foreign keys, dosage, form, instructions, and active (boolean, default true)
  - Add database indexes on prescription_id, drug_id, and active
  - Implement `belongs_to :prescription`, `belongs_to :drug`, `has_many :medication_schedules, dependent: :destroy`, and `has_many :medication_logs, dependent: :destroy`
  - Add dosage and form presence validations
  - Add `active` and `inactive` scopes
  - Write model tests: validations, associations, active/inactive scopes, cascade behavior
  - Create fixtures for medication test data
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.7, 3.8_

- [ ] 1.4 Create the MedicationSchedule model with migration, validations, and day-of-week JSON handling
  - Create the `medication_schedules` table with medication_id foreign key, time_of_day, days_of_week (text for JSON), dosage_amount, and instructions
  - Add database index on medication_id
  - Implement `belongs_to :medication` and `has_many :medication_logs, dependent: :destroy`
  - Configure `serialize :days_of_week, coder: JSON`
  - Add time_of_day and days_of_week presence validations plus custom validation for at least one day selected
  - Add `for_day` scope using SQLite `json_each()` and `ordered_by_time` scope
  - Write model tests: validations (including empty days_of_week), JSON serialization round-trip, for_day scope filtering, ordered_by_time scope
  - Create fixtures for schedule test data
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.7, 4.8_

- [ ] 1.5 Create the MedicationLog model with migration, validations, and upsert support
  - Create the `medication_logs` table with medication_id, medication_schedule_id foreign keys, status (integer enum), logged_at (datetime), scheduled_date (date), and reason (text)
  - Add unique composite index on (medication_schedule_id, scheduled_date), plus indexes on medication_id and scheduled_date
  - Implement `belongs_to :medication` and `belongs_to :medication_schedule`
  - Configure `enum :status, { taken: 0, skipped: 1 }`
  - Add scheduled_date presence validation and medication_schedule_id uniqueness scoped to scheduled_date
  - Add `for_date` and `for_period` scopes
  - Write model tests: enum behavior, uniqueness constraint, scopes, association
  - Create fixtures for log test data
  - _Requirements: 7.1, 7.2, 7.5, 7.7_

- [ ] 2. Drug search service and external API integration
- [ ] 2.1 Implement the DrugSearchService with local-first search and RxNorm API fallback
  - Create the `app/services/` directory (first service object in the project) and establish the Result object pattern
  - Implement the search flow: query local drugs table first, then call RxNorm `getDrugs` endpoint if no local matches
  - Parse RxNorm JSON response, extracting entries filtered by term type (SCD, SBD), and create local Drug records from the results
  - Use Ruby stdlib `Net::HTTP` with a 5-second timeout for RxNorm requests
  - Handle API unavailability gracefully: log warning and return local results only
  - Enforce minimum 2-character query length before performing any search
  - Return a Result object indicating success/error and data source (local vs API)
  - Write service tests: local-only results, API call when no local matches, API failure fallback, Drug record creation from API data, short query rejection
  - Stub HTTP requests in tests using WebMock
  - _Requirements: 1.4, 1.5, 1.6, 1.7_

- [ ] 2.2 (P) Create the DrugsController search endpoint returning HTML fragments for autocomplete
  - Implement a search action at `GET /drugs/search?q=term` that delegates to DrugSearchService
  - Return HTML `<li>` fragments with `data-autocomplete-value` set to the Drug ID, suitable for stimulus-autocomplete consumption
  - Return an empty response for queries shorter than 2 characters
  - Add the drug search route to the routes file
  - Write controller tests: successful search, empty results, short query handling
  - _Requirements: 1.4, 1.5, 1.6_

- [ ] 2.3 (P) Pin stimulus-autocomplete via importmap and create the drug-search Stimulus controller
  - Pin `stimulus-autocomplete` in the importmap configuration
  - Register the autocomplete controller in the Stimulus application
  - Create a `drug-search` Stimulus controller that wraps stimulus-autocomplete with the correct URL for the `/drugs/search` endpoint
  - Ensure the hidden input captures the selected Drug ID and the text input displays the drug name
  - _Requirements: 1.4, 3.5_

- [ ] 3. Prescription management with full CRUD
- [ ] 3.1 Implement the PrescriptionsController with all CRUD actions scoped to the current user
  - Create the PrescriptionsController with index, show, new, create, edit, update, and destroy actions
  - Scope all queries through `Current.user.prescriptions` to enforce data isolation
  - Use strong parameters permitting doctor_name, prescribed_date, and notes
  - Implement cascading destroy that removes all associated medications, schedules, and logs
  - Add RESTful resource routes for prescriptions
  - Display appropriate flash messages for create, update, and delete operations
  - Write controller tests: full CRUD cycle, user scoping (cannot access other user's prescriptions), cascading delete, validation error handling
  - _Requirements: 2.4, 2.5, 2.6, 2.7, 10.1, 10.2, 10.3, 10.5_

- [ ] 3.2 (P) Create prescription views: index with active medication counts, show with medication list, and form partial
  - Build the index view displaying prescriptions ordered by prescribed date (most recent first), showing the count of active medications per prescription
  - Build the show view displaying prescription details and its associated medications
  - Build the form partial with fields for doctor_name, prescribed_date, and notes, reused by new and edit views
  - Apply mobile-first responsive layout using Tailwind CSS utility classes
  - _Requirements: 2.7, 2.8, 11.2_

- [ ] 4. Medication entry with drug autocomplete
- [ ] 4.1 Implement the MedicationsController for CRUD nested under prescriptions with Turbo Frame responses
  - Create the MedicationsController with new, create, edit, update, destroy, and toggle actions
  - Use shallow nesting: collection actions nested under prescriptions, member actions flat
  - Scope medication access through the current user's prescriptions chain
  - Use strong parameters permitting drug_id, dosage, form, instructions, and active
  - Respond with Turbo Frame updates for create, update, and destroy to avoid full page reloads
  - Implement the toggle action that switches medication active/inactive status via Turbo Stream
  - Add medication routes with shallow nesting and the custom toggle member route
  - Write controller tests: nested creation, drug association, Turbo Frame responses, active toggle, user scoping
  - _Requirements: 3.5, 3.6, 3.7, 3.8, 10.1, 10.2, 10.3, 10.5_

- [ ] 4.2 (P) Create medication views: form with drug autocomplete, medication list partial, and toggle control
  - Build the medication form with a drug search autocomplete input powered by the drug-search Stimulus controller, plus fields for dosage, form (select: tablet, capsule, liquid, etc.), and instructions
  - Build a medication list partial rendered within the prescription show view inside a Turbo Frame
  - Add an active/inactive toggle control on each medication item that submits via Turbo Stream
  - Visually distinguish inactive medications in the list
  - _Requirements: 3.5, 3.6, 3.7, 3.8, 11.4_

- [ ] 5. Complex dosing schedule management
- [ ] 5.1 Implement the MedicationSchedulesController with Turbo Stream responses for dynamic schedule building
  - Create the MedicationSchedulesController with create, update, and destroy actions
  - Use shallow nesting under medications for the create action, flat routes for update and destroy
  - Scope schedule access through the current user's prescriptions chain
  - Use strong parameters permitting time_of_day, dosage_amount, instructions, and days_of_week array
  - Respond with Turbo Streams: append for create, replace for update, remove for destroy
  - Add schedule routes with shallow nesting
  - Write controller tests: creation with day-of-week array, Turbo Stream response format, user scoping
  - _Requirements: 4.5, 4.6, 10.1, 10.2, 10.3, 10.5_

- [ ] 5.2 (P) Create the schedule-builder Stimulus controller and schedule form views
  - Build a schedule-builder Stimulus controller that manages dynamic addition and removal of schedule entry forms
  - Create the schedule entry form with time-of-day input, day-of-week checkboxes (Mon-Sun), optional dosage amount override, and conditional instructions
  - Render each schedule entry as a Turbo Frame for server-driven updates
  - Build a schedule list view within the medication detail, showing all configured schedule entries
  - Support multiple schedules per medication to represent different doses at different times
  - _Requirements: 4.5, 4.6, 4.7, 4.8_

- [ ] 6. Daily schedule view with timezone awareness
- [ ] 6.1 Implement the DailyScheduleQuery to compute the daily medication schedule
  - Create the `app/queries/` directory (first query object in the project)
  - Fetch active medications for the user through their prescriptions
  - Filter medication schedules by the target date's day of week using the `for_day` scope
  - Join with MedicationLog records for the target date to determine each entry's status (pending, taken, or skipped)
  - Group results by time_of_day, sorted chronologically
  - Identify overdue entries where the scheduled time has passed with no log
  - Default the date parameter to `Time.zone.today` to respect the user's configured timezone
  - Use eager loading to prevent N+1 queries across medications, schedules, drugs, and logs
  - Write query tests: correct day-of-week filtering, log status merging, overdue detection, timezone-aware date default, inactive medication exclusion
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.7_

- [ ] 6.2 Implement the SchedulesController daily action and daily schedule view
  - Create the SchedulesController with a `show` action for the daily view at `GET /schedule`
  - Accept an optional `date` query parameter for day navigation; default to today
  - Delegate schedule computation to DailyScheduleQuery
  - Build the daily schedule view displaying entries grouped by time of day, showing drug name, dosage, form, and conditional instructions per entry
  - Visually indicate each entry's status: pending, taken, or skipped
  - Highlight overdue medications that are past their scheduled time with no log
  - Add previous/next day navigation controls
  - Add the schedule route
  - Write controller tests: daily view with correct entries, date parameter navigation, default to today
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [ ] 7. Medication logging with Turbo Stream updates
- [ ] 7.1 Implement the MedicationLogsController for taken/skipped logging and undo via Turbo Stream
  - Create the MedicationLogsController with create and destroy actions
  - Implement idempotent upsert in create: use `find_or_initialize_by(medication_schedule_id, scheduled_date)` to prevent duplicate logs
  - Set `logged_at` to `Time.current` automatically on log creation
  - Use strong parameters permitting medication_id, medication_schedule_id, scheduled_date, status, and reason
  - Destroy action serves as undo, returning the entry to pending state
  - All responses via Turbo Stream to replace the schedule entry in place without full page reload
  - Add medication log routes
  - Write controller tests: taken creation, skipped creation with reason, idempotent upsert (updates existing), undo (destroy), Turbo Stream response format
  - _Requirements: 7.1, 7.2, 7.3, 7.5, 7.6, 7.7, 10.1, 10.2, 10.5_

- [ ] 7.2 (P) Create the medication-log Stimulus controller and quick-action UI on daily schedule entries
  - Build a medication-log Stimulus controller that manages button state during Turbo Stream requests (disable buttons while processing)
  - Add taken and skipped quick-action buttons directly on each schedule entry in the daily view
  - Add an undo button that appears after a dose is logged, allowing the user to revert to pending
  - Include an optional reason text field when skipping a dose
  - Ensure each schedule entry has a unique Turbo Stream target DOM ID for in-place replacement
  - _Requirements: 7.3, 7.4, 7.6_

- [ ] 8. Weekly schedule overview
- [ ] 8.1 Implement the WeeklyScheduleQuery to compute the 7-day schedule overview
  - Reuse DailyScheduleQuery for each day of the week to maintain consistent logic
  - Eager-load associations once to avoid N+1 queries across the 7-day span
  - Calculate per-day adherence summary: total scheduled, total logged, and adherence status (complete, partial, none, or empty)
  - Default week_start to the current week's Monday
  - Write query tests: 7-day span correctness, adherence status per day, week boundary handling
  - _Requirements: 6.1, 6.2, 6.4, 6.5_

- [ ] 8.2 Implement the SchedulesController weekly action and weekly overview view
  - Add a `weekly` action to the SchedulesController at `GET /schedule/weekly`
  - Accept an optional `week_start` query parameter for week navigation
  - Delegate computation to WeeklyScheduleQuery
  - Build the weekly view displaying each day as a column or section with medication name, dosage, and time
  - Load the weekly view using a Turbo Frame for efficient rendering
  - Visually distinguish days with all doses logged, partially logged, and no doses logged
  - Add previous/next week navigation controls
  - Add the weekly route
  - Write controller tests: weekly view content, week navigation, Turbo Frame response
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 9. Adherence history with heatmap visualization
- [ ] 9.1 Implement the AdherenceCalculationService for adherence statistics
  - Create the service with configurable time periods (7, 30, or 90 days)
  - Calculate per-medication adherence: total scheduled doses (based on schedule entries and day-of-week rules), total taken, total skipped, and total missed (scheduled minus taken minus skipped)
  - Calculate daily adherence percentages for each day in the period (ratio of taken to total scheduled)
  - Calculate an overall adherence percentage across all medications
  - Return an AdherenceSummary Data object containing medication_stats, daily_adherence hash, and overall_percentage
  - Write service tests: percentage calculation correctness, period boundary correctness, missed dose counting, empty schedule handling, medication with no logs
  - _Requirements: 8.1, 8.2, 8.5_

- [ ] 9.2 Implement the AdherenceController and adherence history view with calendar heatmap
  - Create the AdherenceController with an index action at `GET /adherence`
  - Accept optional period (7, 30, 90) and date query parameters; default period to 30 days
  - Delegate computation to AdherenceCalculationService
  - Build the adherence history view with a per-medication statistics table showing total scheduled, taken, skipped, missed, and percentage
  - Build a pure CSS/HTML calendar heatmap using CSS Grid, with each day cell receiving a CSS custom property (`--intensity`) representing the daily adherence ratio, and color mapped via CSS
  - When the user clicks a specific day in the heatmap, display detailed log entries for that day
  - Add period selection controls (7, 30, 90 day buttons)
  - Add aria-label attributes on heatmap day cells for accessibility
  - Add the adherence route
  - Write controller tests: default period, period selection, date detail view
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 10. Printable medication plan
- [ ] 10.1 Implement the printable plan view with print-optimized Tailwind CSS
  - Add a `print` action to the SchedulesController at `GET /schedule/print`
  - Render all active medications with their complete schedules organized by time-of-day groups (morning, midday, evening, night)
  - Display for each medication: drug name, dosage, form, schedule times, days of the week, and conditional instructions
  - Apply Tailwind `print:` variant classes: hide navigation and interactive elements, ensure black text on white background, clean table layout
  - Add a print button that triggers `window.print()`
  - Add the print route
  - Write controller test: print view renders all active medications
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 11. Navigation, loading indicators, and integration wiring
- [ ] 11.1 Update the shared navbar with medication navigation links and add Turbo loading indicator
  - Add navigation links to the shared navbar for: daily schedule, weekly overview, prescriptions list, and adherence history
  - Add a Turbo loading progress indicator that displays during Turbo navigation
  - Ensure navigation is responsive and functions on mobile viewports from 320px and up
  - _Requirements: 11.1, 11.2, 11.5_

- [ ] 11.2 (P) Verify flash message display for all medication CRUD operations
  - Confirm that create, update, and delete operations across prescriptions, medications, schedules, and logs display appropriate success or error flash messages
  - Ensure flash messages render correctly within Turbo Frame and Turbo Stream responses
  - _Requirements: 11.3, 11.4_

- [ ] 12. End-to-end system tests
- [ ] 12.1 Write a system test covering the complete medication workflow
  - Test the full flow: create a prescription, add a medication with drug search, configure a dosing schedule, navigate to the daily schedule, and log a dose as taken
  - Verify Turbo Frame and Turbo Stream interactions work end-to-end in the browser
  - _Requirements: 2.4, 3.5, 4.5, 5.1, 7.1_

- [ ]* 12.2 (P) Write system tests for printable plan and adherence history
  - Test navigating to the print view and verifying the print-optimized layout includes all active medications organized by time of day
  - Test navigating to the adherence history view, selecting a time period, and clicking a day for detail
  - _Requirements: 8.3, 8.4, 9.1, 9.4_

- [ ]* 12.3 (P) Write a system test verifying mobile-responsive navigation
  - Test the medication navigation on a small viewport (320px width)
  - Verify all navigation links are accessible and the layout adapts correctly
  - _Requirements: 11.1, 11.2_
