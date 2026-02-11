# Requirements Document

## Introduction

This specification covers **Phase 1: Medication Management Core** of the Avicen personal health management application. The goal is to enable authenticated users to manually define, track, and manage their medications. This phase builds on top of the existing Phase 0 foundation (User authentication, Profile, PWA) and introduces the core domain models for drugs, prescriptions, medications, schedules, and medication logging. It also provides the user interface for entering prescriptions, viewing medication schedules, and tracking daily adherence.

The system subject used throughout is "the Medication Service" referring to the Avicen application's medication management subsystem.

---

## Requirements

### Requirement 1: Drug Reference Data

**Objective:** As a user, I want to search for drugs by name when adding a medication, so that I can quickly find the correct drug with accurate information.

#### Acceptance Criteria

1. The Medication Service shall store drug records with a name, RxCUI identifier, and active ingredients.
2. The Medication Service shall validate that each drug record has a name present.
3. The Medication Service shall validate that each drug record has a unique RxCUI identifier when one is provided.
4. When a user types at least 2 characters in the drug search field, the Medication Service shall return matching drug results within 300 milliseconds for locally cached entries.
5. When no matching drug is found locally and an external API query returns results, the Medication Service shall create local drug records from those results for future lookups.
6. If the external drug API is unavailable, the Medication Service shall allow users to manually enter a drug name and proceed without API-sourced data.
7. The Medication Service shall provide a service object that queries the OpenFDA or RxNorm API and returns structured drug data.

---

### Requirement 2: Prescription Management

**Objective:** As a user, I want to create, view, edit, and archive prescriptions, so that I can organize my medications by the prescriptions they belong to.

#### Acceptance Criteria

1. The Medication Service shall associate each prescription with exactly one authenticated user.
2. The Medication Service shall store prescription records with a doctor name, prescribed date, and optional notes.
3. The Medication Service shall validate that each prescription has a prescribed date present.
4. When a user creates a prescription, the Medication Service shall scope it to the currently authenticated user.
5. The Medication Service shall only allow users to view, edit, and delete their own prescriptions.
6. When a user deletes a prescription, the Medication Service shall also delete all associated medications and their schedules and logs.
7. The Medication Service shall display the list of prescriptions ordered by prescribed date (most recent first).
8. The Medication Service shall display the count of active medications for each prescription in the list view.

---

### Requirement 3: Medication Entry

**Objective:** As a user, I want to add medications to a prescription with dosage information and link them to known drugs, so that I can accurately represent what I have been prescribed.

#### Acceptance Criteria

1. The Medication Service shall associate each medication with exactly one prescription and exactly one drug.
2. The Medication Service shall store medication records with a dosage (e.g., "50mg"), a form (e.g., "tablet", "capsule", "liquid"), and an optional instruction text.
3. The Medication Service shall validate that each medication has a dosage present.
4. The Medication Service shall validate that each medication has a drug reference present.
5. When a user adds a medication, the Medication Service shall provide drug search with autocomplete using Stimulus-driven dynamic input.
6. When a user saves a medication, the Medication Service shall update the prescription view using Turbo Frame without a full page reload.
7. The Medication Service shall support an active/inactive status on each medication so users can pause a medication without deleting it.
8. When a user sets a medication to inactive, the Medication Service shall exclude it from daily schedule views and tracking.

---

### Requirement 4: Complex Dosing Schedules

**Objective:** As a user, I want to define flexible dosing schedules with different times, days, and dosage variations, so that I can accurately represent real-world medication regimens (e.g., different morning and evening doses, alternate-day dosing).

#### Acceptance Criteria

1. The Medication Service shall associate each schedule with exactly one medication.
2. The Medication Service shall store schedule records with a time of day, days of the week, a dosage amount for that specific schedule, and optional conditional instructions.
3. The Medication Service shall validate that each schedule has a time of day present.
4. The Medication Service shall validate that each schedule has at least one day of the week selected.
5. The Medication Service shall allow multiple schedules per medication to represent different doses at different times (e.g., 50mg morning, 25mg evening).
6. When a user adds or removes a schedule entry, the Medication Service shall update the schedule builder form dynamically using Stimulus without a full page reload.
7. The Medication Service shall support day-of-week variations (e.g., medication only on Monday, Wednesday, Friday).
8. The Medication Service shall store conditional instructions for context-dependent dosing (e.g., "take with food", "take on empty stomach").

---

### Requirement 5: Daily Medication Schedule View

**Objective:** As a user, I want to see a clear daily view of all medications I need to take today, organized by time of day, so that I know what to take and when.

#### Acceptance Criteria

1. When a user navigates to the daily schedule view, the Medication Service shall display all active medications scheduled for the current date, grouped by time of day.
2. The Medication Service shall display for each scheduled entry: the drug name, dosage, form, and any conditional instructions.
3. The Medication Service shall visually indicate the status of each scheduled dose (pending, taken, or skipped) for the current day.
4. While the user has a timezone configured in their profile, the Medication Service shall calculate and display schedule times in the user's local timezone.
5. When no timezone is configured, the Medication Service shall use UTC as the default timezone.
6. The Medication Service shall allow the user to navigate to the previous or next day's schedule view.
7. The Medication Service shall highlight overdue medications that have not been logged past their scheduled time.

---

### Requirement 6: Weekly Schedule Overview

**Objective:** As a user, I want to see a weekly overview of my medication schedule, so that I can plan ahead and verify that my schedule is correctly configured.

#### Acceptance Criteria

1. When a user navigates to the weekly schedule view, the Medication Service shall display all active medications for each day of the current week.
2. The Medication Service shall display each day as a column or section with the medication name, dosage, and time of day.
3. The Medication Service shall load the weekly view using Turbo Frames for efficient rendering.
4. The Medication Service shall allow the user to navigate between weeks (previous and next).
5. The Medication Service shall visually distinguish between days with all doses logged, partially logged, and no doses logged.

---

### Requirement 7: Medication Tracking (Logging)

**Objective:** As a user, I want to mark my medications as taken or skipped, so that I can maintain an accurate record of my medication adherence.

#### Acceptance Criteria

1. When a user marks a scheduled medication as taken, the Medication Service shall create a medication log record with a taken status, the current timestamp, and the associated medication and schedule.
2. When a user marks a scheduled medication as skipped, the Medication Service shall create a medication log record with a skipped status and an optional reason.
3. The Medication Service shall update the schedule view immediately via Turbo Stream after a log action without requiring a full page reload.
4. The Medication Service shall provide quick-action buttons (taken/skipped) directly on each scheduled entry in the daily view.
5. If a user attempts to log the same schedule entry for the same day twice, the Medication Service shall update the existing log record rather than creating a duplicate.
6. The Medication Service shall allow a user to undo a log action (change from taken back to pending, or from skipped back to pending) for the current day.
7. The Medication Service shall record the exact timestamp when a dose was logged, in addition to the scheduled time.

---

### Requirement 8: Adherence History

**Objective:** As a user, I want to see my medication adherence history over time, so that I can understand my compliance patterns and share them with my doctor.

#### Acceptance Criteria

1. The Medication Service shall provide an adherence history view displaying logged medication data over a configurable time period (7 days, 30 days, 90 days).
2. The Medication Service shall calculate an adherence percentage for each medication as the ratio of taken doses to total scheduled doses in the selected period.
3. The Medication Service shall display a calendar heatmap visualization showing daily adherence (color-coded by percentage: full, partial, missed).
4. When a user selects a specific day in the adherence history, the Medication Service shall display the detailed log entries for that day.
5. The Medication Service shall display adherence summary statistics per medication: total scheduled, total taken, total skipped, and total missed (not logged).

---

### Requirement 9: Printable Medication Plan

**Objective:** As a user, I want to generate a printable or downloadable medication plan, so that I can share a clear schedule with caregivers or keep a physical copy.

#### Acceptance Criteria

1. When a user requests a printable medication plan, the Medication Service shall generate a formatted view of all active medications with their complete schedules.
2. The Medication Service shall include for each medication: drug name, dosage, form, schedule times, days of the week, and conditional instructions.
3. The Medication Service shall provide a print-optimized CSS layout that renders cleanly when using the browser's print function.
4. The Medication Service shall organize the printable plan by time of day (morning, midday, evening, night) for easy daily reference.

---

### Requirement 10: Data Scoping and Authorization

**Objective:** As a user, I want to be certain that my medication data is private and only accessible to me, so that my health information remains secure.

#### Acceptance Criteria

1. The Medication Service shall require authentication for all medication-related actions.
2. The Medication Service shall scope all database queries for prescriptions, medications, schedules, and logs to the currently authenticated user.
3. If a user attempts to access a prescription or medication that does not belong to them, the Medication Service shall return a not-found response.
4. The Medication Service shall never expose medication data belonging to other users in any view, API response, or URL enumeration.
5. The Medication Service shall use Rails strong parameters to prevent mass assignment of user-scoped attributes.

---

### Requirement 11: Navigation and User Experience

**Objective:** As a user, I want intuitive navigation between medication features with responsive, mobile-first design, so that I can manage my medications on any device.

#### Acceptance Criteria

1. The Medication Service shall provide a navigation structure that allows users to access: daily schedule, weekly overview, prescriptions list, and adherence history.
2. The Medication Service shall implement a mobile-first responsive layout that functions well on screen widths from 320px and above.
3. When a user performs create, update, or delete actions, the Medication Service shall display appropriate success or error flash messages.
4. The Medication Service shall use Turbo Frames and Turbo Streams to minimize full page reloads during standard CRUD workflows.
5. While the application is in a loading state during Turbo navigation, the Medication Service shall display a visual loading indicator.
