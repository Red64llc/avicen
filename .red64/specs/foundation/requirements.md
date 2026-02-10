# Requirements Document

## Project Description (Input)
implement phase 0 "Foundation" from file docs/IMPLEMENTATION_PLAN.md

## Introduction

Phase 0 "Foundation" establishes the core infrastructure for Avicen, a personal health management application. The goal is to deliver a deployed Rails 8 app with working authentication, a basic user profile, PWA installability, and a polished landing experience. The existing codebase already includes Rails 8.1 scaffolding with authentication (User, Session, Password models), Tailwind CSS, Hotwire, and Solid Stack. This specification covers the remaining Foundation deliverables: user profile management, PWA activation, post-login dashboard, public landing page, and deployment readiness.

## Requirements

### Requirement 1: User Profile Management

**Objective:** As a user, I want to create and manage my personal profile (name, date of birth, timezone), so that the application can personalize my health management experience.

#### Acceptance Criteria

1. When a user completes registration, the Application shall redirect the user to a profile setup page.
2. The Profile model shall belong to the User model with a one-to-one association.
3. The Application shall store profile fields: name (string), date_of_birth (date), and timezone (string).
4. When a user submits the profile form with valid data, the Application shall save the profile and redirect to the dashboard with a success notice.
5. If a user submits the profile form with missing required fields, the Application shall display validation error messages and re-render the form with status 422.
6. The Application shall validate that name is present on the Profile model.
7. When a user visits the settings page, the Application shall display the current profile data in an editable form.
8. When a user updates their profile, the Application shall save the changes and confirm the update with a success notice.
9. The Application shall scope all profile access to the currently authenticated user.
10. The Application shall use Turbo Frames for profile form updates to avoid full-page reloads.

### Requirement 2: PWA Configuration and Installability

**Objective:** As a user, I want to install Avicen on my phone as a progressive web app, so that I can access it like a native application without visiting the browser.

#### Acceptance Criteria

1. The Application shall serve a valid PWA manifest at the `/manifest.json` route.
2. The Application shall include a manifest link tag in the application layout HTML head.
3. The PWA manifest shall declare the app name as "Avicen", display mode as "standalone", and appropriate theme and background colors.
4. The Application shall register a service worker via the `/service-worker.js` route.
5. The service worker shall provide an offline fallback page when the network is unavailable.
6. The Application shall include appropriate PWA meta tags (apple-mobile-web-app-capable, mobile-web-app-capable, theme-color) in the layout.
7. When a user visits the application in a supported browser, the Application shall meet PWA installability criteria (manifest, service worker, HTTPS).
8. The PWA manifest shall include icon entries in at least one size (512x512) with both regular and maskable purposes.

### Requirement 3: Post-Login Dashboard

**Objective:** As an authenticated user, I want to see a personalized dashboard after logging in, so that I have a central hub to access my health information.

#### Acceptance Criteria

1. When an authenticated user visits the root path, the Application shall display the dashboard page.
2. The dashboard shall greet the user by name if a profile with a name exists.
3. The dashboard shall display a prompt to complete the profile if the user has not yet created one.
4. The Application shall require authentication for the dashboard page.
5. The dashboard shall serve as the after-authentication redirect target.
6. The Application shall render the dashboard using a dedicated DashboardController.

### Requirement 4: Public Landing Page

**Objective:** As a visitor, I want to see an informative landing page that explains the application and provides login/signup options, so that I understand the value of Avicen before creating an account.

#### Acceptance Criteria

1. When an unauthenticated user visits the root path, the Application shall display the public landing page.
2. The landing page shall include a brief description of the Avicen application.
3. The landing page shall provide a visible link or button to the login page.
4. The landing page shall provide a visible link or button to the registration page.
5. The Application shall allow unauthenticated access to the landing page.
6. When an already-authenticated user visits the landing page URL, the Application shall redirect to the dashboard.

### Requirement 5: User Registration

**Objective:** As a visitor, I want to create an account with email and password, so that I can start using Avicen for my health management.

#### Acceptance Criteria

1. The Application shall provide a registration page accessible without authentication.
2. When a visitor submits the registration form with a valid email and password, the Application shall create a new user account and start an authenticated session.
3. If a visitor submits the registration form with an email that already exists, the Application shall display a validation error.
4. The Application shall validate that the email address is present and unique (case-insensitive).
5. The Application shall validate that the password meets minimum length requirements.
6. When registration succeeds, the Application shall redirect the user to the profile setup page.
7. The Application shall normalize email addresses by stripping whitespace and downcasing.

### Requirement 6: Application Layout and Navigation

**Objective:** As a user, I want a consistent and responsive navigation layout, so that I can easily move between sections of the application.

#### Acceptance Criteria

1. The Application shall render a responsive navigation bar on all authenticated pages.
2. The navigation shall include links to the dashboard and profile/settings.
3. The navigation shall include a logout action.
4. While a user is authenticated, the Application shall display the user's name or email in the navigation.
5. The Application shall use a mobile-first responsive layout with Tailwind CSS.
6. The Application shall use the application layout for all pages, with appropriate conditional content for authenticated vs. unauthenticated states.

### Requirement 7: Deployment Readiness

**Objective:** As a developer, I want the application to be configured for production deployment, so that the app can be deployed and accessed over HTTPS.

#### Acceptance Criteria

1. The Application shall include a health check endpoint at `/up` that returns HTTP 200 when the app is running.
2. The Application shall be configured to use Solid Queue for background jobs in production.
3. The Application shall be configured to use Solid Cache for caching in production.
4. The Application shall be configured to use Solid Cable for Action Cable in production.
5. The Application shall store secrets using Rails encrypted credentials.
6. The Application shall include a Dockerfile suitable for container-based deployment.
7. The Application shall serve assets via Propshaft with proper cache headers.
8. If the application receives a request without HTTPS in production, the Application shall enforce SSL redirection.

### Requirement 8: Timezone Support

**Objective:** As a user, I want the application to respect my timezone preference, so that all date and time displays are accurate for my location.

#### Acceptance Criteria

1. The Application shall store the user's preferred timezone in their profile.
2. When a user has a timezone set in their profile, the Application shall apply that timezone to all date and time displays during the request.
3. The profile form shall present a dropdown of valid timezone options.
4. If a user has not set a timezone, the Application shall default to UTC for date and time operations.
5. The Application shall use the `Time.use_zone` pattern within a controller around-action to set the timezone per request.
