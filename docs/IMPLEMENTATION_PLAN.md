# Avicen - Implementation Plan (Rails 8)

## Overview

Avicen is a personal health management app designed to help users (and caregivers) track medications, biology reports, and correlate health data from multiple sources. This plan outlines a phased approach to building a mobile-first app using **Rails 8** with **Hotwire Native** for iOS/Android deployment.

---

## Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Framework | **Rails 8** | "One Person Framework", batteries included |
| Frontend | **Hotwire** (Turbo + Stimulus) | Server-rendered, minimal JS, real-time updates |
| UI | **Tailwind CSS + ViewComponent** | Rapid prototyping, component reuse |
| Database | **SQLite** (dev) / **PostgreSQL** (prod) | Rails 8 SQLite production-ready, Postgres for scale |
| Background Jobs | **Solid Queue** | Database-backed, no Redis needed |
| Caching | **Solid Cache** | Database-backed caching |
| WebSockets | **Solid Cable** | Real-time updates without Redis |
| Auth | **Rails 8 Authentication** (built-in) | Native generator, no gems needed |
| Storage | **Active Storage + S3** | Document/image storage |
| AI/OCR | **Claude API + Vision** | Prescription/report scanning |
| Mobile | **Hotwire Native** | Native iOS/Android from Rails views |
| Health APIs | **Apple HealthKit, Withings API** | Health data import |
| PWA | **Built-in (Rails 8)** | Service worker + manifest by default |

---

## Phase 0: Foundation (Bootstrap)

**Goal:** Rails 8 app with auth, PWA, deployable and installable on phone.

### Features

1. **Project Scaffolding**
   ```bash
   rails new avicen --css=tailwind --database=sqlite3
   ```
   - Rails 8 with Tailwind CSS
   - SQLite for simplicity (swap to Postgres later if needed)
   - Hotwire included by default
   - PWA files generated automatically

2. **Authentication System**
   ```bash
   rails generate authentication
   ```
   - Rails 8 built-in authentication generator
   - Email/password with secure sessions
   - Password reset flow included
   - No Devise needed

3. **Basic User Profile**
   - User model with profile fields (name, DOB, timezone)
   - Settings page with Turbo Frame updates
   - Time zone preference for medication schedules

4. **PWA Configuration**
   - Service worker in `app/views/pwa/service-worker.js`
   - Manifest in `app/views/pwa/manifest.json`
   - "Add to Home Screen" ready
   - Offline page fallback

5. **Deployment**
   - Deploy to **Render**, **Fly.io**, or **Railway**
   - HTTPS required (for camera/voice APIs)
   - Environment variables for secrets

### Deliverable
A deployed Rails 8 app with authentication, installable as PWA on phone.

### Commands
```bash
# Create app
rails new avicen --css=tailwind --database=sqlite3
cd avicen

# Add authentication
rails generate authentication

# Add ViewComponent for UI components
bundle add view_component

# Generate User profile
rails generate scaffold Profile user:references name:string date_of_birth:date timezone:string

# Run migrations
rails db:migrate

# Start server
bin/dev
```

---

## Phase 1: Medication Management Core

**Goal:** Enable users to manually define, track, and manage medications.

### Features

1. **Drug Database Integration**
   - Service object to query OpenFDA or RxNorm API
   - Stimulus controller for autocomplete search
   - Local Drug model for caching searched drugs
   ```ruby
   # app/models/drug.rb
   class Drug < ApplicationRecord
     # name, active_ingredients, contraindications, rxcui
   end
   ```

2. **Prescription Data Model**
   ```ruby
   # app/models/prescription.rb
   class Prescription < ApplicationRecord
     belongs_to :user
     belongs_to :doctor, optional: true
     has_many :medications, dependent: :destroy
   end

   # app/models/medication.rb
   class Medication < ApplicationRecord
     belongs_to :prescription
     belongs_to :drug
     has_many :schedules, dependent: :destroy
     has_many :medication_logs, dependent: :destroy
   end

   # app/models/schedule.rb (complex dosing)
   class Schedule < ApplicationRecord
     belongs_to :medication
     # time_of_day, days_of_week[], dosage, conditional_on
   end
   ```

3. **Medication Entry UI**
   - Turbo Frame forms for smooth UX
   - Stimulus controller for dynamic schedule builder
   - Support morning/evening different doses
   - Day-of-week variations

4. **Medication Schedule View**
   - Daily calendar view (ViewComponent)
   - Weekly overview with Turbo Frames
   - Printable "easy-to-follow plan" (PDF via Prawn or browser print CSS)

5. **Medication Tracking**
   - Mark medications as taken/skipped with Turbo Stream updates
   - Quick-action buttons
   - Adherence history with calendar heatmap

### Deliverable
Users can manually enter prescriptions and track medication adherence.

---

## Phase 2: Reminders & Notifications

**Goal:** Proactive medication reminders via push notifications.

### Features

1. **Push Notification Infrastructure**
   - Rails 8 **Action Notifier** (new in Rails 8)
   - Web Push API integration
   - Store push subscriptions in database
   ```ruby
   # app/notifiers/medication_notifier.rb
   class MedicationNotifier < ApplicationNotifier
     def reminder(medication_log)
       # Send push notification
     end
   end
   ```

2. **Smart Reminders**
   - Solid Queue jobs for scheduled notifications
   - `MedicationReminderJob` runs on schedule
   - Missed dose detection and alerts
   - Refill reminders based on quantity tracking

3. **Quick Actions**
   - Notification actions: "Taken", "Snooze 30min"
   - Service worker handles action clicks
   - Turbo Stream updates when returning to app

### Deliverable
Users receive push notifications and can confirm intake with one tap.

---

## Phase 3: Biology Reports

**Goal:** Store and visualize biology/lab test results over time.

### Features

1. **Biology Report Data Model**
   ```ruby
   # app/models/biology_report.rb
   class BiologyReport < ApplicationRecord
     belongs_to :user
     has_many :test_results, dependent: :destroy
     has_one_attached :document  # Active Storage
   end

   # app/models/test_result.rb
   class TestResult < ApplicationRecord
     belongs_to :biology_report
     belongs_to :biomarker
     # value, unit, reference_min, reference_max, flagged
   end

   # app/models/biomarker.rb
   class Biomarker < ApplicationRecord
     # name, code, default_unit, typical_reference_range
     # e.g., TSH, T3, T4, Hemoglobin
   end
   ```

2. **Manual Report Entry**
   - Form with biomarker autocomplete
   - Auto-fill reference ranges from Biomarker model
   - Flag out-of-range values automatically

3. **Report Visualization**
   - Chartkick + Groupdate for trend charts
   - Individual biomarker history view
   - Reference range bands on charts
   ```erb
   <%= line_chart @tsh_results.group_by_day(:tested_at).average(:value),
                  library: { annotation: { reference_range: [0.4, 4.0] } } %>
   ```

4. **Report Storage**
   - Active Storage for PDF/image attachments
   - Full-text search with pg_search or SQLite FTS

### Deliverable
Users can enter lab results and view trends over time with charts.

---

## Phase 4: AI-Powered Document Scanning

**Goal:** Automatically extract data from prescriptions and biology reports using Claude Vision.

### Features

1. **Document Capture**
   - Simple file input with camera capture:
   ```erb
   <%= file_field_tag :document, accept: "image/*", capture: "environment",
                      data: { controller: "camera", action: "change->camera#upload" } %>
   ```
   - Stimulus controller for preview and upload
   - Direct upload to Active Storage

2. **Prescription Scanning**
   ```ruby
   # app/services/prescription_scanner.rb
   class PrescriptionScanner
     def initialize(image_blob)
       @image_blob = image_blob
     end

     def scan
       client = Anthropic::Client.new

       response = client.messages.create(
         model: "claude-sonnet-4-20250514",
         max_tokens: 1024,
         messages: [{
           role: "user",
           content: [
             { type: "image", source: { type: "base64", media_type: @image_blob.content_type, data: base64_image } },
             { type: "text", text: prescription_prompt }
           ]
         }]
       )

       JSON.parse(response.content.first.text)
     end
   end
   ```
   - Extract: drug names, dosages, frequencies, duration
   - Return structured JSON for review
   - User confirms before saving

3. **Biology Report Scanning**
   - Similar service for lab reports
   - Extract biomarker names, values, units, reference ranges
   - Handle various lab report formats

4. **Scan Flow UI**
   - Turbo Frame for scan → review → confirm flow
   - Editable fields pre-populated from AI
   - Confidence indicators

### Deliverable
Users scan documents with camera, AI extracts data, users confirm and save.

---

## Phase 5: Health Data Integration

**Goal:** Import health metrics from Apple Health and Withings.

### Features

1. **Apple HealthKit Integration**
   - Via Hotwire Native bridge component (Phase 10)
   - Or: Manual export/import of Apple Health data
   - Import: heart rate, HRV, sleep, steps

2. **Withings API Integration**
   ```ruby
   # app/services/withings_client.rb
   class WithingsClient
     include HTTParty
     base_uri 'https://wbsapi.withings.net'

     def fetch_measurements(user)
       # OAuth2 flow, fetch weight, BP, sleep
     end
   end
   ```
   - OAuth flow for account connection
   - Background job for periodic sync
   - Webhook endpoint for real-time updates

3. **Unified Health Dashboard**
   - ViewComponent cards for each metric type
   - Turbo Frames for lazy loading
   - Daily/weekly/monthly toggle

4. **Data Export**
   - JSON/CSV export controller
   - FHIR-compatible format (optional)

### Deliverable
Users connect health sources and see unified dashboard.

---

## Phase 6: Correlation & Insights

**Goal:** Help users understand relationships between medications, biology, and health metrics.

### Features

1. **Timeline View**
   - Unified timeline with all events
   - ViewComponent for each event type
   - Stimulus controller for filtering/zooming
   - Hotwire lazy loading for performance

2. **Correlation Analysis**
   - Overlay charts: medication changes vs. biomarker trends
   - Claude API for insight generation:
   ```ruby
   # app/services/insight_generator.rb
   class InsightGenerator
     def generate(user)
       context = build_health_context(user)
       # Ask Claude to identify correlations
     end
   end
   ```

3. **Insight Display**
   - "Your TSH improved 2 weeks after dosage increase"
   - Cards with AI-generated insights
   - Shareable insight summaries

4. **Custom Notes & Events**
   - Simple note model for symptoms, side effects
   - Tag system for categorization

### Deliverable
Users see correlations between treatment and health outcomes.

---

## Phase 7: Caregiver & Sharing Features

**Goal:** Enable caregivers to manage health data for family members.

### Features

1. **Multi-Profile Support**
   ```ruby
   # app/models/managed_profile.rb
   class ManagedProfile < ApplicationRecord
     belongs_to :caregiver, class_name: 'User'
     belongs_to :patient, class_name: 'User'
     # role: :viewer, :editor, :admin
   end
   ```
   - Profile switcher in nav
   - Scoped queries based on current profile

2. **Caregiver Permissions**
   - Invitation system via email
   - Pundit policies for authorization
   - Activity log with PaperTrail

3. **Practitioner Sharing**
   - Signed, time-limited share links
   - PDF export for doctor visits (Prawn gem)
   - QR code generation (rqrcode gem)

4. **Family Dashboard**
   - Overview of all managed profiles
   - Alert aggregation

### Deliverable
Jane can manage her father's medications and share reports with doctors.

---

## Phase 8: Voice Interface

**Goal:** Voice-based medication entry and tracking.

### Features

1. **Web Speech API Integration**
   ```javascript
   // app/javascript/controllers/voice_controller.js
   import { Controller } from "@hotwired/stimulus"

   export default class extends Controller {
     static targets = ["status", "transcript"]

     connect() {
       const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
       this.recognition = new SpeechRecognition()
       this.recognition.continuous = false
       this.recognition.lang = 'en-US'

       this.recognition.onresult = (event) => {
         const transcript = event.results[0][0].transcript
         this.processCommand(transcript)
       }
     }

     listen() {
       this.recognition.start()
       this.statusTarget.textContent = "Listening..."
     }

     processCommand(transcript) {
       fetch('/voice_commands', {
         method: 'POST',
         headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.csrfToken },
         body: JSON.stringify({ transcript })
       })
     }
   }
   ```

2. **Voice Command Parser**
   ```ruby
   # app/services/voice_command_parser.rb
   class VoiceCommandParser
     COMMANDS = {
       /took my (morning|evening|night) (medications?|meds)/i => :mark_taken,
       /skip (.*) dose/i => :skip_dose,
       /what medications/i => :list_medications
     }

     def parse(transcript)
       COMMANDS.each do |pattern, action|
         if match = transcript.match(pattern)
           return { action: action, params: match.captures }
         end
       end
       { action: :unknown }
     end
   end
   ```

3. **Voice Feedback**
   - Text-to-speech confirmations
   - "Got it! Marked your morning medications as taken."

4. **Accessibility**
   - High contrast mode
   - Large touch targets
   - Screen reader optimization

### Deliverable
Users can say "I took my morning medications" and have it logged.

---

## Phase 9: Safety & Conflict Detection

**Goal:** Detect drug interactions and prescription conflicts.

### Features

1. **Drug Interaction Database**
   - OpenFDA drug interaction API
   - Local cache of common interactions
   - Severity levels: major, moderate, minor

2. **Automatic Conflict Detection**
   ```ruby
   # app/services/interaction_checker.rb
   class InteractionChecker
     def check(medications)
       medications.combination(2).flat_map do |med_a, med_b|
         find_interactions(med_a.drug, med_b.drug)
       end
     end
   end
   ```
   - Run on prescription save
   - Check across all active medications
   - Food-drug interaction warnings

3. **Safety Alerts**
   - Turbo Stream alerts on conflict detection
   - Push notification for critical interactions
   - Shareable report for doctors

4. **Allergy Tracking**
   - Allergy model linked to drug ingredients
   - Cross-reference on new prescriptions

### Deliverable
Users are warned about dangerous drug interactions.

---

## Phase 10: Native Apps with Hotwire Native

**Goal:** Deploy to iOS and Android app stores.

### Features

1. **Hotwire Native Setup**
   - iOS app shell (Swift, minimal code)
   - Android app shell (Kotlin, minimal code)
   - Configure path mappings

2. **Bridge Components**
   - **Camera component** for native photo capture
   - **HealthKit component** for Apple Health access
   - **Push notification component** for native notifications
   ```swift
   // CameraComponent.swift
   final class CameraComponent: BridgeComponent {
       override class var name: String { "camera" }

       override func onReceive(message: Message) {
           if message.event == "capture" {
               presentCamera()
           }
       }
   }
   ```

3. **App Store Submission**
   - iOS: TestFlight → App Store
   - Android: Internal testing → Play Store
   - Privacy policy, terms of service

4. **Localization**
   - Rails I18n for multi-language
   - English + French support
   - Regional drug databases

### Deliverable
Native iOS and Android apps in app stores.

---

## Data Model Overview

```
User
├── Profile
│   ├── name, date_of_birth, timezone
│   └── preferences (JSON)
├── ManagedProfiles[] (caregiver relationships)
├── Prescriptions[]
│   ├── doctor_name, prescribed_at
│   └── Medications[]
│       ├── Drug (cached from API)
│       ├── Schedules[] (complex dosing)
│       └── MedicationLogs[] (taken/skipped)
├── BiologyReports[]
│   ├── tested_at, lab_name
│   ├── document (Active Storage)
│   └── TestResults[]
│       ├── Biomarker
│       ├── value, unit
│       └── reference_min, reference_max
├── HealthMetrics[]
│   ├── source (apple_health/withings)
│   ├── metric_type, value, recorded_at
├── Allergies[]
├── Notes[] (symptoms, side effects)
└── PushSubscriptions[]
```

---

## Key Technical Decisions

### Why Rails 8?
- "One Person Framework" - ship fast with minimal complexity
- Built-in auth, PWA, background jobs (Solid Queue)
- SQLite production-ready for MVP
- Hotwire for real-time without heavy JS

### Why SQLite First?
- Zero configuration
- Single file database
- Production-ready in Rails 8 with Solid gems
- Easy switch to Postgres when needed

### Why Hotwire Native over Capacitor?
- Server-rendered views = single source of truth
- Updates deploy without app store approval
- Bridge components for native features when needed
- 37signals battle-tested (HEY, Basecamp)

### Why Claude for AI?
- Best-in-class vision for document scanning
- Excellent medical terminology understanding
- Ruby SDK available (anthropic gem)

### Security Considerations
- Rails built-in protections (CSRF, XSS, SQL injection)
- Encrypted credentials (`rails credentials:edit`)
- HTTPS required for camera/voice APIs
- phi_attrs gem for HIPAA logging if needed
- Regular dependency updates with `bundle audit`

---

## Red64 CLI Workflow

```bash
# Start new feature branch
red64 start --feature "medication-tracking"

# Red64 enforces:
# 1. REQUIREMENTS.md creation
# 2. DESIGN.md creation
# 3. Test-first development (RSpec/Minitest)
# 4. Code review gates
# 5. Atomic commits

# Resume interrupted work
red64 resume

# Autonomous mode
red64 --sandbox -y
```

---

## Success Criteria per Phase

| Phase | Key Metric |
|-------|------------|
| 0 | App installable as PWA, user can sign up |
| 1 | User can add and track 1 medication |
| 2 | User receives working push notification |
| 3 | User can view TSH trend over 3+ data points |
| 4 | Prescription scanned with >80% accuracy |
| 5 | Withings data visible in app |
| 6 | User can see medication vs. biomarker correlation |
| 7 | Caregiver can view dependent's medications |
| 8 | Voice command successfully logs medication |
| 9 | Drug interaction alert fires correctly |
| 10 | iOS/Android app available via TestFlight/Play Store |

---

## Quick Start Commands

```bash
# Create Rails 8 app
rails new avicen --css=tailwind --database=sqlite3
cd avicen

# Add gems
bundle add anthropic        # Claude API
bundle add view_component   # UI components
bundle add chartkick        # Charts
bundle add groupdate        # Date grouping
bundle add pagy             # Pagination
bundle add pundit           # Authorization

# Generate auth
rails generate authentication

# Generate core models
rails generate model Drug name:string rxcui:string active_ingredients:text
rails generate model Prescription user:references doctor_name:string prescribed_at:date
rails generate model Medication prescription:references drug:references dosage:string
rails generate model MedicationLog medication:references taken_at:datetime status:integer

# Run migrations
rails db:migrate

# Start dev server
bin/dev
```

---

## Next Steps

1. **Review this plan** and adjust priorities if needed
2. **Run Quick Start Commands** to scaffold the app
3. **Begin Phase 0** - get a deployed PWA with auth
4. **Phase 1-4** - core medication + scanning for demo
5. **Iterate** through remaining phases

---

*This plan supports both John (self-managing thyroid condition) and Jane (caring for father with microvascularite) use cases from the requirements.*
