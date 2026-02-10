# Gap Analysis: Foundation

---
**Purpose**: Analyze the gap between requirements and existing codebase to inform implementation strategy decisions.

**Approach**:
- Provide analysis and options, not final implementation choices
- Offer multiple viable alternatives when applicable
- Flag unknowns and constraints explicitly
- Align with existing patterns and architecture limits
---

## Executive Summary

- **Scope**: 8 requirements covering user profile management, PWA activation, post-login dashboard, public landing page, user registration, application layout/navigation, deployment readiness, and timezone support.
- **Key Findings**: The codebase is a freshly scaffolded Rails 8.1 app with authentication (User, Session, Password models) already in place. However, it lacks a registration flow, Profile model, dashboard, landing page, navigation layout, and PWA activation. Deployment infrastructure (Dockerfile, Kamal, Solid Stack) is scaffolded but needs configuration hardening (SSL, assume_ssl).
- **Primary Challenges**: No registration controller exists (Rails 8 auth generator does not include sign-up). The PWA manifest and service worker exist as templates but are commented out in both routes and the layout. The root route currently points to the login page, requiring rerouting logic for authenticated vs. unauthenticated users.
- **Recommended Approach**: Hybrid (Option C) -- extend existing authentication infrastructure and layout while creating new controllers (RegistrationsController, DashboardController, PagesController), a new Profile model with migration, and new views for dashboard, landing page, profile, and navigation.

## Current State Investigation

### Domain-Related Assets

| Category | Assets Found | Location | Notes |
|----------|--------------|----------|-------|
| User Model | `User` with `has_secure_password`, email normalization, `has_many :sessions` | `app/models/user.rb` | No validations for email uniqueness/presence in model (relies on DB constraint). No `has_one :profile` yet. |
| Session Model | `Session` with `belongs_to :user` | `app/models/session.rb` | Minimal, standard Rails 8 auth. |
| Current Model | `Current` with session attribute, delegates `user` | `app/models/current.rb` | Ready for use across controllers. |
| Authentication Concern | Full auth concern with `require_authentication`, `allow_unauthenticated_access`, session management | `app/controllers/concerns/authentication.rb` | Solid foundation. `after_authentication_url` defaults to `root_url`. |
| Sessions Controller | Login/logout with rate limiting | `app/controllers/sessions_controller.rb` | No registration actions. |
| Passwords Controller | Password reset flow | `app/controllers/passwords_controller.rb` | Complete with rate limiting and token-based reset. |
| Application Layout | Basic HTML layout with Tailwind, Turbo, meta tags | `app/views/layouts/application.html.erb` | Has some PWA meta tags (`apple-mobile-web-app-capable`, `mobile-web-app-capable`). Manifest link is commented out. No navigation bar. |
| PWA Manifest | JSON manifest with app name "Avicen", standalone display, 512x512 icon | `app/views/pwa/manifest.json.erb` | Exists but route is commented out. Colors set to "red" (placeholder). |
| Service Worker | Empty template with push notification code commented out | `app/views/pwa/service-worker.js` | No offline fallback functionality. Route commented out. |
| Dockerfile | Multi-stage build with Ruby 3.4.7, jemalloc, Thruster | `Dockerfile` | Production-ready. Uses `bin/thrust` for HTTP caching/compression. |
| Kamal Deploy Config | Service configuration with volume mounts, SSL proxy section commented out | `config/deploy.yml` | Placeholder IP. SSL not enabled. |
| Database Config | SQLite3 with separate prod databases for cache, queue, cable | `config/database.yml` | Solid Stack databases configured. |
| Production Config | Solid Cache, Solid Queue configured. SSL commented out. | `config/environments/production.rb` | `force_ssl` and `assume_ssl` are commented out. |
| Stylesheets | Empty `application.css` (Tailwind handles styling) | `app/assets/stylesheets/application.css` | Tailwind CSS via `tailwindcss-rails` gem. |
| JavaScript | Standard Stimulus setup with importmap, includes hello_controller | `app/javascript/` | Ready for new Stimulus controllers. |
| Test Infrastructure | Minitest with parallel execution, fixtures, `SessionTestHelper` | `test/` | `sign_in_as` helper available. Only basic tests exist. |
| Health Check | `/up` endpoint configured | `config/routes.rb` | Standard Rails health check. |

### Architecture Patterns

- **Dominant patterns**: Standard Rails 8 MVC with Hotwire (Turbo + Stimulus), session-based authentication via concern, Tailwind CSS for styling, Propshaft for assets, Importmap for JS.
- **Naming conventions**: Standard Rails (singular models, plural controllers, snake_case files).
- **Dependency direction**: Controllers include Authentication concern; Current attributes pattern for request-scoped user access.
- **Testing approach**: Minitest with fixtures, integration tests for controllers, `SessionTestHelper` for authenticated test requests.

### Integration Surfaces

- **Data models/schemas**: `users` table (email_address, password_digest), `sessions` table (user_id, ip_address, user_agent). No `profiles` table.
- **API clients**: None.
- **Auth mechanisms**: Cookie-based sessions via `Authentication` concern. `Current.user` available in all controllers/views. `authenticated?` helper available in views.

## Requirements Feasibility Analysis

### Technical Needs (from Requirements)

| Requirement | Technical Need | Category | Complexity |
|-------------|----------------|----------|------------|
| R1: User Profile Management | New `Profile` model (name, date_of_birth, timezone), migration, `ProfilesController`, profile views (new/edit), Turbo Frames for form updates | Data Model + UI + Logic | Moderate |
| R2: PWA Configuration | Uncomment and configure PWA routes, update manifest colors/description, implement service worker with offline fallback, add manifest link in layout, verify meta tags | Configuration + UI | Simple |
| R3: Post-Login Dashboard | New `DashboardController`, dashboard view with greeting and profile prompt, authenticated root routing | UI + Logic | Simple |
| R4: Public Landing Page | New `PagesController` (or similar), landing page view with description and auth links, unauthenticated access, root routing for unauthenticated users | UI + Logic | Simple |
| R5: User Registration | New `RegistrationsController` with `new`/`create` actions, registration view, User model validations (email presence/uniqueness, password length), post-registration redirect to profile setup | Controller + UI + Logic | Moderate |
| R6: Application Layout & Navigation | Update `application.html.erb` with responsive nav bar, conditional content for auth/unauth states, mobile-first Tailwind styling | UI | Moderate |
| R7: Deployment Readiness | Enable `force_ssl` and `assume_ssl` in production config, verify Solid Stack config, verify Dockerfile, verify health check, verify credentials setup, verify Propshaft cache headers | Configuration | Simple |
| R8: Timezone Support | Timezone field in Profile model (covered by R1), controller `around_action` with `Time.use_zone`, timezone dropdown in profile form, UTC default | Logic + UI | Simple |

### Gap Analysis

| Requirement | Gap Type | Description | Impact |
|-------------|----------|-------------|--------|
| R1.1 (Post-registration redirect to profile setup) | Missing | No registration flow exists; redirect logic must be built from scratch | High |
| R1.2 (Profile model with one-to-one association) | Missing | `Profile` model, migration, and `has_one :profile` on User do not exist | High |
| R1.3 (Profile fields: name, date_of_birth, timezone) | Missing | No profiles table in schema | High |
| R1.10 (Turbo Frame for profile updates) | Missing | No Turbo Frame usage in current views | Medium |
| R2.1 (PWA manifest at /manifest.json) | Missing | Route exists but is commented out in `config/routes.rb` | Medium |
| R2.4 (Service worker registration) | Missing | Route exists but is commented out; service worker has no actual functionality | Medium |
| R2.5 (Offline fallback page) | Missing | Service worker is entirely commented out boilerplate | Medium |
| R2.6 (PWA meta tags) | Partial | `apple-mobile-web-app-capable` and `mobile-web-app-capable` exist in layout. Missing: `theme-color` meta tag | Low |
| R2.8 (PWA icons) | Existing | `icon.png` at 512x512 with regular and maskable purposes defined in manifest | Low |
| R3.1-6 (Dashboard) | Missing | No `DashboardController`, no dashboard view, no authenticated root route | High |
| R4.1-6 (Landing page) | Missing | No landing page; root currently points to `sessions#new` | High |
| R4.6 (Authenticated user redirect from landing to dashboard) | Missing | Root route logic does not differentiate by auth state | Medium |
| R5.1-7 (User Registration) | Missing | No `RegistrationsController`, no registration view, no sign-up route | High |
| R5.4 (Email validations in model) | Missing | User model has no explicit `validates` for email -- relies only on DB unique index | Medium |
| R5.5 (Password minimum length) | Missing | No password length validation in User model (`has_secure_password` has a 72-char max only) | Medium |
| R6.1-6 (Navigation layout) | Missing | `application.html.erb` has no navigation bar, no conditional auth/unauth content | High |
| R7.1 (Health check at /up) | Existing | Already configured in routes: `get "up" => "rails/health#show"` | None |
| R7.2-4 (Solid Stack) | Existing | Solid Queue, Cache, and Cable configured in `production.rb` and `database.yml` | None |
| R7.5 (Encrypted credentials) | Existing | Rails credentials infrastructure present (master.key pattern in Dockerfile/deploy) | None |
| R7.6 (Dockerfile) | Existing | Production Dockerfile exists with multi-stage build, Thruster | None |
| R7.7 (Propshaft cache headers) | Existing | `config.public_file_server.headers` set to 1-year cache in production | None |
| R7.8 (SSL enforcement) | Missing | `config.force_ssl` and `config.assume_ssl` are commented out in production.rb | Medium |
| R8.1-4 (Timezone in profile) | Missing | No Profile model (covered by R1 gap). No timezone `around_action`. | Medium |
| R8.5 (Time.use_zone pattern) | Missing | No timezone-aware controller concern or around_action exists | Medium |

**Gap Types**:
- **Missing**: Capability does not exist in current codebase
- **Partial**: Some elements exist but are incomplete
- **Existing**: Already implemented and functional
- **Constraint**: Existing architecture limits implementation options

## Implementation Approach Options

### Option A: Extend Existing Components

**When to consider**: When most requirements can be satisfied by modifying existing files.

**Files/Modules to Extend**:

| File | Change Type | Impact Assessment |
|------|-------------|-------------------|
| `app/models/user.rb` | Extend | Add `has_one :profile`, validations for email (presence, uniqueness, format), password length validation |
| `app/controllers/sessions_controller.rb` | Modify | Change `after_authentication_url` behavior to redirect to dashboard |
| `app/views/layouts/application.html.erb` | Extend | Add navigation bar, PWA manifest link, theme-color meta tag, conditional auth/unauth content |
| `config/routes.rb` | Extend | Uncomment PWA routes, add registration/dashboard/profile/pages routes, change root |
| `app/views/pwa/manifest.json.erb` | Modify | Update colors, description |
| `app/views/pwa/service-worker.js` | Modify | Add offline fallback logic |
| `config/environments/production.rb` | Modify | Uncomment `force_ssl`, `assume_ssl` |
| `app/controllers/concerns/authentication.rb` | Extend | Override `after_authentication_url` to point to dashboard |

**Trade-offs**:
- Minimal new files for auth and routing changes
- Risk of making SessionsController handle registration concerns (anti-pattern)
- Layout file could become bloated with navigation and conditional logic
- Registration logic does not naturally belong in any existing controller

**Verdict**: Not viable as sole approach. Registration, Dashboard, Landing Page, and Profile require new controllers and views.

### Option B: Create New Components

**When to consider**: Feature has distinct responsibility or existing components are already complex.

**New Components Required**:

| Component | Responsibility | Integration Points |
|-----------|----------------|-------------------|
| `Profile` model | Store user profile data (name, DOB, timezone) | `belongs_to :user`, `User has_one :profile` |
| `RegistrationsController` | Handle user sign-up | Uses `Authentication` concern methods (`start_new_session_for`) |
| `DashboardController` | Render post-login dashboard | Requires authentication, accesses `Current.user.profile` |
| `PagesController` | Render public landing page | Allows unauthenticated access, redirects authenticated users |
| `ProfilesController` | CRUD for user profile | Requires authentication, scoped to `Current.user`, uses Turbo Frames |
| `SetTimezone` concern | Apply user timezone per request | `around_action` in `ApplicationController`, reads from `Current.user.profile` |
| `CreateProfiles` migration | Create profiles table | References users, stores name/DOB/timezone |
| Dashboard view | Greeting, profile completion prompt | Reads `Current.user` and profile |
| Landing page view | App description, login/signup links | Links to `new_session_path`, `new_registration_path` |
| Registration view | Email/password sign-up form | Posts to `RegistrationsController#create` |
| Profile views (new/edit) | Profile form with timezone dropdown | Turbo Frame wrapping, `form_with` for Profile |
| Navigation partial | Responsive nav bar | Rendered in layout, uses `authenticated?` helper |
| Offline fallback page | Static HTML for offline state | Served by service worker when network unavailable |

**Trade-offs**:
- Clean separation of concerns (each controller has single responsibility)
- Easier to test in isolation (DashboardController tests, RegistrationsController tests, etc.)
- More files but follows Rails conventions exactly
- Requires careful routing setup for root path differentiation

### Option C: Hybrid Approach (Recommended)

**When to consider**: Complex features requiring both extension and new creation.

**Combination Strategy**:

| Part | Approach | Rationale |
|------|----------|-----------|
| Profile model + migration | Create new | Completely new domain entity |
| RegistrationsController + views | Create new | Distinct responsibility, no existing registration code |
| DashboardController + views | Create new | Separate concern from sessions |
| PagesController + views | Create new | Public pages are a distinct responsibility |
| ProfilesController + views | Create new | CRUD for profile, separate from user auth |
| SetTimezone concern | Create new | Cross-cutting concern, fits in `app/controllers/concerns/` |
| Navigation partial | Create new | `app/views/shared/_navbar.html.erb` or `app/views/layouts/_navigation.html.erb` |
| User model | Extend | Add `has_one :profile`, validations |
| Application layout | Extend | Add nav partial render, PWA link, theme-color, conditional content |
| Routes | Extend | Add all new routes, uncomment PWA routes, change root |
| PWA manifest | Extend | Update placeholder values |
| Service worker | Extend | Add offline fallback cache logic |
| Production config | Extend | Enable SSL settings |
| Authentication concern | Extend | Adjust `after_authentication_url` if needed |

**Phased Implementation**:
1. **Phase 1 (Core models & registration)**: Create Profile model + migration, add User validations, build RegistrationsController with views
2. **Phase 2 (Pages & routing)**: Create DashboardController, PagesController, update root route with conditional logic
3. **Phase 3 (Profile & timezone)**: Create ProfilesController with Turbo Frame forms, add SetTimezone concern
4. **Phase 4 (Layout & navigation)**: Build responsive navigation, update application layout
5. **Phase 5 (PWA)**: Activate PWA routes, update manifest, implement service worker offline fallback
6. **Phase 6 (Deployment)**: Enable SSL, verify all Solid Stack config, smoke test production setup

**Trade-offs**:
- Balanced: leverages existing authentication while creating clean new components
- Incremental: each phase is independently testable
- Follows established Rails conventions throughout
- More planning upfront, but less technical debt

## Effort and Risk Assessment

### Effort Estimate

| Option | Effort | Justification |
|--------|--------|---------------|
| A | Not viable | Cannot satisfy requirements without new controllers |
| B | M (3-7 days) | Multiple new controllers/models/views, but all are standard Rails CRUD patterns with no external integrations |
| C (Recommended) | M (3-7 days) | Same scope as B but organized into incremental phases for safer delivery |

**Effort Scale**:
- **S** (1-3 days): Existing patterns, minimal dependencies, straightforward integration
- **M** (3-7 days): Some new patterns/integrations, moderate complexity
- **L** (1-2 weeks): Significant functionality, multiple integrations or workflows
- **XL** (2+ weeks): Architectural changes, unfamiliar tech, broad impact

### Risk Assessment

| Option | Risk | Justification |
|--------|------|---------------|
| A | High | Not viable as standalone approach; bloats existing components |
| B | Low | All changes use familiar Rails patterns (models, controllers, views, concerns). No external APIs. No complex business logic. |
| C (Recommended) | Low | Same low-risk profile as B with added benefit of phased delivery reducing integration risk |

**Risk Factors**:
- **High**: Unknown tech, complex integrations, architectural shifts, unclear perf/security path
- **Medium**: New patterns with guidance, manageable integrations, known perf solutions
- **Low**: Extend established patterns, familiar tech, clear scope, minimal integration

### Requirement-Level Complexity Breakdown

| Requirement | Effort | Risk | Notes |
|-------------|--------|------|-------|
| R1: User Profile Management | S-M | Low | Standard model + CRUD. Turbo Frame adds slight complexity. |
| R2: PWA Configuration | S | Low | Mostly uncommenting and configuring existing scaffolding. Offline fallback is a small JS addition. |
| R3: Post-Login Dashboard | S | Low | Simple controller with one action and one view. |
| R4: Public Landing Page | S | Low | Simple controller, one view, routing conditional. |
| R5: User Registration | S | Low | Standard controller pattern. Leverages existing `start_new_session_for` from Authentication concern. |
| R6: Application Layout & Navigation | S-M | Low | Tailwind responsive nav. Main effort is design/styling. |
| R7: Deployment Readiness | S | Low | Almost entirely configuration changes. Most infrastructure already scaffolded. |
| R8: Timezone Support | S | Low | Single concern with `around_action`, timezone select in profile form. |

## Recommendations for Design Phase

### Preferred Approach

**Recommended Option**: C (Hybrid)

**Rationale**:
- The existing codebase provides a solid Rails 8 authentication foundation that should be extended (User model, Authentication concern, layout).
- All missing capabilities (registration, profile, dashboard, landing, navigation) are genuinely new concerns that warrant their own controllers and views per Rails conventions.
- The phased delivery strategy allows for incremental testing and validation after each phase.
- No external dependencies or unfamiliar technologies are involved -- everything uses standard Rails 8 patterns.

### Key Decisions Required

1. **Root route strategy**: How to differentiate between authenticated and unauthenticated users at the root path. Options include: (a) a single `RootController` that checks auth and redirects, (b) a constraint-based route using `authenticated` route constraint, or (c) conditional logic in `PagesController#home` that redirects authenticated users.
2. **Profile model design**: Whether Profile should be a separate model (one-to-one with User) as specified in requirements, or whether profile fields should live directly on the User model. Requirements explicitly state a separate Profile model.
3. **Turbo Frame scope for profile**: Decide whether to wrap the entire profile form in a Turbo Frame or use more granular frames for individual sections. Requirements specify Turbo Frame updates to avoid full-page reloads.
4. **Navigation structure**: Whether to use a separate layout for authenticated vs. unauthenticated pages, or a single layout with conditional rendering. Single layout with conditional is simpler and more conventional.
5. **PWA theme colors**: The manifest currently has "red" as placeholder for `theme_color` and `background_color`. Actual brand colors need to be decided.
6. **Timezone handling edge case**: How to handle timezone when a user is authenticated but has no profile yet (e.g., right after registration). Requirements state default to UTC.

### Research Items to Carry Forward

| Item | Priority | Reason |
|------|----------|--------|
| Rails 8 authenticated route constraints | Medium | Determine best pattern for root route differentiation (constraint vs. controller logic) |
| Service worker offline fallback pattern for Rails 8 | Medium | Identify minimal service worker implementation that caches an offline page |
| `has_secure_password` password length validation | Low | Verify if Rails 8.1 `has_secure_password` provides built-in minimum length or if custom validation is needed |
| Tailwind CSS responsive navbar patterns | Low | Reference patterns for mobile hamburger menu with Stimulus controller |

## Out of Scope

Items explicitly deferred to design phase:
- Specific Tailwind color palette and UI design decisions
- Detailed PWA icon asset creation (512x512 already exists, but branding may change)
- Kamal deployment target configuration (IP addresses, registry, proxy/SSL settings)
- Email verification flow (noted as optional in the authentication steering document)
- ViewComponent integration (mentioned in IMPLEMENTATION_PLAN.md but not in Foundation requirements)
- Content Security Policy configuration (currently commented out in initializer)
