# Research & Design Decisions

---
**Purpose**: Capture discovery findings, architectural investigations, and rationale that inform the technical design for the Foundation feature.

**Usage**:
- Log research activities and outcomes during the discovery phase.
- Document design decision trade-offs that are too detailed for `design.md`.
- Provide references and evidence for future audits or reuse.
---

## Summary
- **Feature**: `foundation`
- **Discovery Scope**: Extension (existing Rails 8.1 scaffold with authentication)
- **Key Findings**:
  - Rails 8 built-in authentication does not include route-level constraints; a custom `AuthenticatedConstraint` class is needed for dual-root routing.
  - `has_secure_password` does not enforce a minimum password length; explicit `validates :password, length: { minimum: 8 }` is required.
  - Service worker offline fallback requires a minimal `fetch` event listener plus a cached `offline.html` page; no external libraries needed.

## Research Log

### Authenticated Route Constraints for Dual-Root Routing
- **Context**: Requirements 3.1 and 4.1 specify that the root path serves different content based on authentication state (dashboard vs. landing page). Rails 8's Authentication concern operates at the controller level, not the routing level.
- **Sources Consulted**:
  - [Rails Routing Guide](https://guides.rubyonrails.org/routing.html)
  - [Rails Issue #53296 - Add authentication constraints](https://github.com/rails/rails/issues/53296)
  - [Viget - Using Routing Constraints to Root Your App](https://www.viget.com/articles/using-routing-constraints-to-root-your-app/)
  - [Thoughtbot - Rails Advanced Routing Constraints](https://thoughtbot.com/blog/rails-advanced-routing-constraints)
- **Findings**:
  - Rails 8 does not ship with an `authenticated` routing helper (unlike Devise).
  - A custom constraint class that checks `request.cookie_jar.signed[:session_id]` against the `sessions` table is the standard pattern.
  - The authenticated root must appear before the unauthenticated root in `routes.rb` (top-down matching).
  - Alternative: controller-level redirect (simpler but adds a redirect hop for every unauthenticated visit).
- **Implications**: A lightweight `AuthenticatedConstraint` class in `app/constraints/` provides clean routing without extra redirect hops. This avoids coupling routing logic to any specific controller.

### Service Worker Offline Fallback for Rails 8 PWA
- **Context**: Requirement 2.5 specifies an offline fallback page when the network is unavailable. The existing service worker scaffold is entirely commented-out boilerplate.
- **Sources Consulted**:
  - [Rails 8 PWA by Default](https://www.gauravvarma.dev/blog/rails-8-adds-web-push-notifications-and-improved-pwa-support)
  - [Everything You Need to Ace PWAs in Rails](https://blog.codeminer42.com/everything-you-need-to-ace-pwas/)
  - [Make Your Rails App Work Offline Part 2](https://alicia-paz.medium.com/make-your-rails-app-work-offline-part-2-caching-assets-and-adding-an-offline-fallback-334729ade904)
  - [Building Offline-Capable Rails Apps](https://www.endpointdev.com/blog/2025/08/offline-capable-rails/)
- **Findings**:
  - Rails 8 ships with PWA scaffolding (`app/views/pwa/service-worker.js` and `manifest.json.erb`) but the routes are commented out by default.
  - Minimal offline fallback: (1) cache `/offline.html` during `install` event, (2) intercept failed `fetch` requests for navigation and return the cached page.
  - No external library (Workbox) is needed for this basic use case.
  - The offline page is a static HTML file in `public/offline.html`.
- **Implications**: The service worker implementation is minimal JavaScript (under 30 lines). The `install` event pre-caches the offline page, and the `fetch` event returns it when navigation requests fail.

### Password Length Validation with has_secure_password
- **Context**: Requirement 5.5 requires minimum password length. Need to verify whether Rails 8.1's `has_secure_password` provides built-in minimum length enforcement.
- **Sources Consulted**:
  - [Rails API - ActiveModel::SecurePassword](https://api.rubyonrails.org/v5.1/classes/ActiveModel/SecurePassword/ClassMethods.html)
  - [Rails Issue #14591 - Append password length validation](https://github.com/rails/rails/issues/14591)
  - [Authentication Zero Approach](https://blog.appsignal.com/2025/04/16/pre-build-a-secure-authentication-layer-with-authentication-zero-for-ruby-on-rails.html)
- **Findings**:
  - `has_secure_password` validates: password presence on create, maximum 72 characters (bcrypt limit), and password confirmation match.
  - No minimum length is enforced by default.
  - Custom validation required: `validates :password, length: { minimum: 8 }, if: -> { password.present? }`.
  - The `if` condition prevents the validation from firing on existing records loaded from the database (known Rails quirk).
- **Implications**: The User model must add an explicit password length validation. Using `if: -> { password.present? }` guard ensures the validation only runs when a password is being set.

### Per-Request Timezone with around_action
- **Context**: Requirement 8.5 specifies using the `Time.use_zone` pattern with a controller `around_action` for per-request timezone.
- **Sources Consulted**:
  - [Rails API - Time.use_zone](https://api.rubyonrails.org/classes/Time.html)
  - [Mastering Timezone Handling in Rails](https://lightningrails.beehiiv.com/p/mastering-timezone-handling-in-rails-applications)
  - [Working with Time Zones in Ruby on Rails](https://www.varvet.com/blog/working-with-time-zones-in-ruby-on-rails/)
  - [Time.use_zone for Different Timezones](https://prathamesh.tech/2019/07/11/use-time-use_zone-to-navigate-timezone/)
- **Findings**:
  - `Time.use_zone(zone, &block)` is the recommended pattern; it wraps the request in the user's timezone and resets it afterward.
  - Must use `around_action` (not `before_action` with `Time.zone =`) to avoid timezone leakage between requests.
  - The concern should yield unconditionally, applying the user's timezone when available and defaulting to UTC otherwise.
  - The timezone value stored in the profile must be a valid `ActiveSupport::TimeZone` name.
- **Implications**: A `SetTimezone` concern in `app/controllers/concerns/` with `around_action` is the clean, standard approach. It reads from `Current.user&.profile&.timezone` and defaults to `"UTC"`.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Controller-based redirect | Single root to PagesController, redirect authenticated users | Simplest implementation | Extra redirect hop for every unauthenticated request | Viable but suboptimal |
| Route constraint | Custom `AuthenticatedConstraint` class for dual-root routing | No redirect hop, clean routing, follows Rails conventions | Requires DB lookup per request for unauthenticated root | Selected approach; DB lookup is lightweight (primary key check) |
| Authenticated concern at routing level | Move authentication logic into routes | Reuses existing concern | `Current` attributes not available at routing layer | Not viable |

## Design Decisions

### Decision: Dual-Root Routing via Custom Route Constraint
- **Context**: Requirements 3.1 and 4.1 need different content at the root path depending on authentication state.
- **Alternatives Considered**:
  1. Single PagesController with redirect logic in the action
  2. Custom `AuthenticatedConstraint` class for route-level branching
  3. Middleware-based approach
- **Selected Approach**: Custom `AuthenticatedConstraint` class checking `request.cookie_jar.signed[:session_id]` against the sessions table.
- **Rationale**: Cleanest separation of concerns; routing configuration explicitly declares intent. No redirect overhead. Follows established Rails constraint patterns documented in official guides.
- **Trade-offs**: Adds a lightweight DB query for unauthenticated requests to check if a session exists. This is negligible for the expected traffic patterns of a personal health app.
- **Follow-up**: Verify session cookie name matches the one set in the Authentication concern (`session_id`).

### Decision: Separate Profile Model (Not on User)
- **Context**: Requirement 1.2 explicitly states "Profile model shall belong to the User model with a one-to-one association."
- **Alternatives Considered**:
  1. Add profile fields directly to the `users` table
  2. Separate `profiles` table with `belongs_to :user`
- **Selected Approach**: Separate `Profile` model with `belongs_to :user` and `User has_one :profile`.
- **Rationale**: Requirements explicitly mandate this. Also provides cleaner separation between authentication data (User) and personal data (Profile). Easier to extend profile fields in future phases without touching the auth-critical users table.
- **Trade-offs**: Requires a JOIN or eager-loading when accessing profile data from the user. Negligible performance impact for single-user lookups.

### Decision: Single Application Layout with Conditional Rendering
- **Context**: Requirement 6.6 specifies a single layout with conditional content for authenticated vs. unauthenticated states.
- **Alternatives Considered**:
  1. Separate layouts for authenticated and unauthenticated pages
  2. Single layout with conditional navigation rendering
- **Selected Approach**: Single `application.html.erb` layout with a shared navigation partial that uses `authenticated?` helper for conditional content.
- **Rationale**: Simpler to maintain. The `authenticated?` helper is already available in views. Avoids layout duplication and keeps navigation behavior consistent.
- **Trade-offs**: Slightly more conditional logic in the layout, but this is minimal and well-contained in a partial.

### Decision: Minimal Service Worker Without Workbox
- **Context**: Requirement 2.5 requires an offline fallback page.
- **Alternatives Considered**:
  1. Minimal vanilla JS service worker with fetch interception
  2. Workbox library for advanced caching strategies
- **Selected Approach**: Vanilla JavaScript service worker with `install` (pre-cache offline page) and `fetch` (intercept failed navigation requests) events.
- **Rationale**: The Foundation phase only requires a basic offline fallback, not advanced caching. Adding Workbox introduces unnecessary complexity and an external dependency for a simple use case.
- **Trade-offs**: Less sophisticated caching compared to Workbox. Sufficient for current requirements; can be upgraded in later phases if needed.

## Risks & Mitigations
- **Route constraint DB lookup performance** -- The `AuthenticatedConstraint` performs a `Session.exists?(id:)` query per unauthenticated request. Mitigation: This is a primary key lookup on an indexed column, completing in microseconds for SQLite.
- **Profile-less authenticated state** -- After registration and before profile creation, the user has no profile. Mitigation: Dashboard checks for profile existence and shows a prompt to complete it. Timezone concern defaults to UTC when no profile exists.
- **PWA installability in all browsers** -- Not all browsers support PWA installation. Mitigation: PWA is an enhancement; the application remains fully functional as a regular web app. Requirement 2.7 specifies "in a supported browser."

## References
- [Rails Routing Guide](https://guides.rubyonrails.org/routing.html) -- Official routing documentation
- [Rails 8 Authentication](https://avohq.io/blog/rails-8-authentication) -- Overview of Rails 8 built-in auth
- [Rails Issue #53296](https://github.com/rails/rails/issues/53296) -- Request for authentication constraints
- [Rails 8 PWA Support](https://www.gauravvarma.dev/blog/rails-8-adds-web-push-notifications-and-improved-pwa-support) -- PWA defaults in Rails 8
- [Everything You Need to Ace PWAs in Rails](https://blog.codeminer42.com/everything-you-need-to-ace-pwas/) -- Comprehensive PWA guide
- [Rails API - Time.use_zone](https://api.rubyonrails.org/classes/Time.html) -- Timezone handling API
- [Sign Up and Settings Guide](https://guides.rubyonrails.org/sign_up_and_settings.html) -- Rails guide for registration
