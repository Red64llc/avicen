# Avicen - Implementation Plan

## Overview

Avicen is a personal health management app designed to help users (and caregivers) track medications, biology reports, and correlate health data from multiple sources. This plan outlines a phased approach to building a mobile-first Progressive Web App (PWA) using the Red64 CLI framework.

---

## Technology Stack Recommendation

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Frontend | Next.js 14+ (App Router) | PWA support, SSR, mobile-first |
| UI | Tailwind CSS + shadcn/ui | Rapid prototyping, accessibility |
| Mobile | PWA + Capacitor (optional) | Native-like experience, App Store deployment |
| Backend | Next.js API Routes + tRPC | Type-safe API, co-located with frontend |
| Database | PostgreSQL + Prisma | Relational data, health records structure |
| Auth | NextAuth.js | Secure, supports multiple providers |
| Storage | S3-compatible (Cloudflare R2) | Document/image storage |
| AI/OCR | Claude API + Vision | Prescription/report scanning |
| Health APIs | Apple HealthKit, Withings API | Health data import |

---

## Phase 0: Foundation (Bootstrap)

**Goal:** Establish project structure with Red64 CLI, basic auth, and deployment pipeline.

### Features
1. **Project Scaffolding**
   - Initialize Next.js project with TypeScript
   - Configure Tailwind CSS + shadcn/ui components
   - Set up Prisma with PostgreSQL schema
   - Configure Red64 CLI with TDD enforcement

2. **Authentication System**
   - Email/password authentication
   - OAuth (Google, Apple) for convenience
   - Session management with NextAuth.js

3. **Basic User Profile**
   - User settings page
   - Profile information (name, date of birth)
   - Timezone preferences

4. **PWA Configuration**
   - Service worker setup
   - Manifest file for installability
   - Offline-first architecture foundation

5. **CI/CD Pipeline**
   - GitHub Actions for testing
   - Automated deployment (Vercel/Railway)
   - Environment configuration

### Deliverable
A deployable app skeleton with authentication that can be installed on a phone as a PWA.

---

## Phase 1: Medication Management Core

**Goal:** Enable users to manually define, track, and manage medications.

### Features
1. **Drug Database Integration**
   - Integrate with open drug database (OpenFDA, RxNorm, or French Vidal API)
   - Drug search autocomplete
   - Store drug information (name, active ingredients, contraindications)

2. **Prescription Data Model**
   - Prescription entity (doctor, date, medications)
   - Medication schedule (dosage, frequency, duration)
   - Support for complex schedules:
     - Morning/evening different doses
     - Day-of-week variations
     - Conditional dosing based on biology results

3. **Medication Entry UI**
   - Form-based medication entry
   - Dosage calculator helpers
   - Duration and refill tracking

4. **Medication Schedule View**
   - Daily medication calendar
   - Weekly overview
   - "Easy-to-follow plan" printable view for complex regimens

5. **Medication Tracking**
   - Mark medications as taken/skipped
   - Snooze reminders
   - Adherence history log

### Deliverable
Users can manually enter prescriptions and track medication adherence with a clear schedule view.

---

## Phase 2: Reminders & Notifications

**Goal:** Proactive medication reminders via push notifications.

### Features
1. **Push Notification Infrastructure**
   - Web Push API integration
   - Notification permission flow
   - Notification preferences (times, frequency)

2. **Smart Reminders**
   - Scheduled medication reminders
   - Missed dose alerts
   - Refill reminders based on remaining supply

3. **Quick Actions**
   - One-tap "taken" confirmation from notification
   - Snooze for 15/30/60 minutes
   - View medication details

### Deliverable
Users receive timely reminders and can confirm medication intake directly from notifications.

---

## Phase 3: Biology Reports

**Goal:** Store and visualize biology/lab test results over time.

### Features
1. **Biology Report Data Model**
   - Report entity (date, lab, type)
   - Test results (biomarkers, values, units, reference ranges)
   - Support for common tests: TSH, T3, T4, CBC, CMP, etc.

2. **Manual Report Entry**
   - Form for entering test results
   - Biomarker autocomplete with standard reference ranges
   - Flag out-of-range values

3. **Report Visualization**
   - Individual biomarker trend charts
   - Historical comparison
   - Normal range indicators

4. **Report Storage**
   - Attach original document (PDF/image)
   - Searchable report history

### Deliverable
Users can manually enter lab results and view trends over time with clear visualizations.

---

## Phase 4: AI-Powered Document Scanning

**Goal:** Automatically extract data from prescriptions and biology reports using AI vision.

### Features
1. **Document Capture**
   - Camera integration for photo capture
   - Image upload from gallery
   - PDF upload support

2. **Prescription Scanning**
   - Claude Vision API integration
   - Extract: drug names, dosages, frequencies, duration
   - Confidence scoring and human verification step
   - Auto-populate medication forms

3. **Biology Report Scanning**
   - Extract test names, values, units, reference ranges
   - Handle various lab report formats
   - OCR for printed and handwritten annotations

4. **Email Report Import**
   - Parse biology reports from email attachments
   - Connect email account (optional)
   - Or forward emails to dedicated address

### Deliverable
Users can scan documents with their camera and have data auto-extracted, reducing manual entry.

---

## Phase 5: Health Data Integration

**Goal:** Import health metrics from Apple Health and Withings.

### Features
1. **Apple HealthKit Integration**
   - Capacitor plugin for native access (or HealthKit web export)
   - Import: heart rate, HRV, sleep, respiratory rate, activity
   - Periodic sync configuration
   - Historical data import

2. **Withings API Integration**
   - OAuth flow for Withings account
   - Import: weight, blood pressure, sleep, activity
   - Webhook for real-time updates

3. **Unified Health Dashboard**
   - Combined view of all health metrics
   - Daily/weekly/monthly summaries
   - Customizable metric display

4. **Data Export**
   - Export all data as JSON/CSV
   - FHIR-compatible export (future-proofing)

### Deliverable
Users can connect Apple Health and Withings to see all health data in one place.

---

## Phase 6: Correlation & Insights

**Goal:** Help users understand relationships between medications, biology, and health metrics.

### Features
1. **Timeline View**
   - Unified timeline: medications, reports, health events
   - Filter by category
   - Zoom in/out (day/week/month)

2. **Correlation Analysis**
   - Visual overlay: medication changes vs. biomarker trends
   - Health metrics vs. medication adherence
   - AI-suggested correlations (Claude analysis)

3. **Insight Generation**
   - "Your TSH improved after medication adjustment on X date"
   - "Sleep quality correlates with medication adherence"
   - Exportable insight summaries

4. **Custom Notes & Events**
   - Log symptoms, side effects, lifestyle changes
   - Tag events for correlation tracking

### Deliverable
Users can visualize and understand how their treatment affects their health over time.

---

## Phase 7: Caregiver & Sharing Features

**Goal:** Enable caregivers to manage health data for family members.

### Features
1. **Multi-Profile Support**
   - Add dependent profiles (e.g., aging parent)
   - Switch between profiles
   - Per-profile data isolation

2. **Caregiver Permissions**
   - Invite caregivers by email
   - Role-based access (view, edit, manage)
   - Activity log for accountability

3. **Practitioner Sharing**
   - Generate shareable report links (time-limited)
   - Export formatted PDF for doctor visits
   - QR code for quick sharing

4. **Family Dashboard**
   - Overview of all managed profiles
   - Alerts across profiles

### Deliverable
Caregivers like Jane can manage their father's health data and share with practitioners.

---

## Phase 8: Voice Interface

**Goal:** Enable voice-based medication entry and tracking for accessibility.

### Features
1. **Voice Medication Entry**
   - "Add prescription: Levothyroxine 50mcg, once daily morning"
   - Natural language parsing
   - Confirmation before saving

2. **Voice Tracking**
   - "I took my morning medications"
   - "Skip evening dose"
   - Voice confirmation feedback

3. **Voice Queries**
   - "What medications do I take today?"
   - "When is my next dose?"
   - "What was my last TSH result?"

4. **Accessibility Improvements**
   - Screen reader optimization
   - High contrast mode
   - Large text support

### Deliverable
Users can interact with Avicen entirely through voice for hands-free operation.

---

## Phase 9: Safety & Conflict Detection

**Goal:** Detect drug interactions and prescription conflicts.

### Features
1. **Drug Interaction Database**
   - Integrate interaction checker (DrugBank, OpenFDA)
   - Severity classification (major, moderate, minor)
   - Evidence references

2. **Automatic Conflict Detection**
   - Check new prescriptions against existing medications
   - Alert on interactions across doctors' prescriptions
   - Food-drug interaction warnings

3. **Safety Alerts**
   - Push notification for critical interactions
   - In-app warning banners
   - Shareable conflict report for doctors

4. **Allergy Tracking**
   - Store known allergies
   - Cross-reference with prescription ingredients

### Deliverable
Users are protected from dangerous drug interactions, especially when seeing multiple specialists.

---

## Phase 10: Polish & Native Apps

**Goal:** Optimize UX and optionally deploy to app stores.

### Features
1. **Performance Optimization**
   - Lazy loading
   - Image optimization
   - Offline data sync

2. **Native App Wrapper (Optional)**
   - Capacitor build for iOS/Android
   - Native HealthKit integration
   - App Store submission

3. **Onboarding Flow**
   - Guided setup wizard
   - Import existing data
   - Permission explanations

4. **Localization**
   - Multi-language support (English, French)
   - Regional drug databases
   - Date/time format preferences

### Deliverable
A polished, production-ready app suitable for app store distribution.

---

## Data Model Overview

```
User
├── Profile
│   ├── PersonalInfo
│   └── Preferences
├── ManagedProfiles[] (for caregivers)
├── Prescriptions[]
│   ├── Doctor
│   ├── Date
│   └── Medications[]
│       ├── Drug (→ DrugDatabase)
│       ├── Dosage
│       ├── Schedule (complex)
│       └── Duration
├── MedicationLogs[]
│   ├── Medication
│   ├── Timestamp
│   └── Status (taken/skipped/snoozed)
├── BiologyReports[]
│   ├── Date
│   ├── Lab
│   ├── Document (file)
│   └── Results[]
│       ├── Biomarker
│       ├── Value
│       ├── Unit
│       └── ReferenceRange
├── HealthMetrics[]
│   ├── Source (AppleHealth/Withings)
│   ├── Type
│   ├── Value
│   └── Timestamp
├── Allergies[]
└── SharedAccess[]
    ├── SharedWith (User/Email)
    └── Permissions
```

---

## Key Technical Decisions

### Why PWA First?
- Single codebase for web and mobile
- No app store approval delays during development
- Can add Capacitor later for native features

### Why PostgreSQL?
- Health data is inherently relational
- Strong data integrity guarantees
- HIPAA-compliant hosting options available

### Why Claude for AI?
- Best-in-class vision for document scanning
- Excellent at medical terminology extraction
- Can provide insight generation and correlation analysis

### Security Considerations
- All health data encrypted at rest
- HTTPS only
- No third-party analytics with health data
- GDPR/HIPAA-aware data handling
- Regular security audits

---

## Red64 CLI Workflow

For each phase, use Red64 CLI with:

```bash
# Start new feature branch
red64 start --feature "medication-tracking"

# Red64 will enforce:
# 1. REQUIREMENTS.md creation
# 2. DESIGN.md creation
# 3. Test-first development
# 4. Code review gates
# 5. Atomic commits

# Resume interrupted work
red64 resume

# Run in autonomous mode (with guardrails)
red64 --sandbox -y
```

---

## Success Criteria per Phase

| Phase | Key Metric |
|-------|------------|
| 0 | App installable on phone, user can sign up |
| 1 | User can add and track 1 medication |
| 2 | User receives working push notification |
| 3 | User can view TSH trend over 3+ data points |
| 4 | Prescription scanned with >80% accuracy |
| 5 | Apple Health data visible in app |
| 6 | User can see medication vs. biomarker correlation |
| 7 | Caregiver can view dependent's medications |
| 8 | Voice command successfully logs medication |
| 9 | Drug interaction alert fires correctly |
| 10 | App passes app store review |

---

## Next Steps

1. **Review this plan** and adjust priorities if needed
2. **Set up Red64 CLI** with the project
3. **Begin Phase 0** to establish the foundation
4. **Iterate** through phases, validating with real use cases

---

*This plan supports both John (self-managing thyroid condition) and Jane (caring for father with microvascularite) use cases from the requirements.*
