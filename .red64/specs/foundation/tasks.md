# Implementation Plan

- [x] 1. Create the Profile model with migration and extend the User model
- [x] 1.1 Create the Profile model, database migration, and one-to-one association with User
  - Generate the profiles table with user reference (unique foreign key), name (required), date_of_birth (optional), and timezone (optional)
  - Define the Profile model with belongs_to :user, name presence validation, and timezone inclusion validation against ActiveSupport::TimeZone names
  - Add has_one :profile (dependent: destroy) to the User model
  - Verify the unique index on user_id enforces the one-to-one constraint
  - _Requirements: 1.2, 1.3, 1.6, 8.1_

- [x] 1.2 Add registration validations to the User model
  - Add email_address presence and case-insensitive uniqueness validation to supplement the existing database unique index
  - Add password minimum length validation (8 characters) with a guard condition so it only runs when a password value is being set
  - Preserve the existing email normalization and has_secure_password behavior
  - _Requirements: 5.3, 5.4, 5.5, 5.7_

- [x] 1.3 Create fixtures and unit tests for Profile and User models
  - Write Profile model tests covering name presence validation, timezone inclusion validation, belongs_to association, and rejection of duplicate user_id
  - Write User model tests covering email presence, case-insensitive uniqueness, password minimum length, has_one profile association, and dependent destroy behavior
  - Create profile fixtures for use in subsequent controller tests
  - _Requirements: 1.2, 1.3, 1.6, 5.3, 5.4, 5.5, 8.1_

- [x] 2. Implement user registration
- [x] 2.1 Build the RegistrationsController with new and create actions
  - Allow unauthenticated access to the registration actions
  - On successful registration, create the User record, start an authenticated session using the existing Authentication concern method, and redirect to the profile setup page
  - On validation failure, re-render the registration form with error messages and a 422 status
  - Apply rate limiting consistent with the existing sessions controller pattern
  - Use strong parameters permitting only email_address, password, and password_confirmation
  - _Requirements: 5.1, 5.2, 5.3, 5.6, 1.1_

- [x] 2.2 Create the registration view with form and routes
  - Build the registration form with email, password, and password_confirmation fields, displaying inline validation errors
  - Add the singular registration resource route (new and create actions only)
  - _Requirements: 5.1, 5.2, 5.4, 5.5_

- [x] 2.3 Write controller tests for registration
  - Test successful registration creates a user and session, then redirects to profile setup
  - Test invalid data (missing fields, short password) re-renders the form with 422
  - Test duplicate email shows a validation error
  - Test rate limiting applies to the create action
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 1.1_

- [x] 3. Implement the Profile controller and views
- [x] 3.1 Build the ProfilesController with new, create, edit, and update actions
  - Require authentication for all actions (inherit default)
  - Scope all profile access to the currently authenticated user, using Current.user to build or retrieve the profile
  - On successful creation, redirect to the dashboard with a success notice
  - On successful update, respond with a Turbo Frame replacement or redirect with a success notice
  - On validation failure, re-render the form with error messages and a 422 status
  - Use strong parameters permitting name, date_of_birth, and timezone
  - _Requirements: 1.4, 1.5, 1.8, 1.9_

- [x] 3.2 Create profile views with a shared form partial and Turbo Frame
  - Build a shared form partial containing name, date_of_birth, and timezone (dropdown populated from ActiveSupport::TimeZone) fields
  - Wrap the form in a Turbo Frame tag to enable partial-page updates without full reloads
  - Create separate new (profile setup) and edit (settings) views that render the shared partial
  - _Requirements: 1.7, 1.10, 8.3_

- [x] 3.3 Add the profile resource route
  - Add the singular profile resource route (new, create, edit, update actions)
  - _Requirements: 1.4, 1.7_

- [x] 3.4 Write controller tests for ProfilesController
  - Test profile creation for the current user redirects to dashboard with notice
  - Test profile update saves changes and confirms with a success notice
  - Test edit action renders the current profile in an editable form
  - Test validation errors re-render the form with 422
  - Test that profile access is scoped exclusively to the authenticated user
  - _Requirements: 1.4, 1.5, 1.7, 1.8, 1.9, 1.10_

- [x] 4. Implement the SetTimezone concern
  - Create a controller concern that wraps each request with the user's preferred timezone using Time.use_zone in an around_action
  - Read the timezone from the authenticated user's profile; default to UTC when no user, no profile, or no timezone is set
  - Include the concern in ApplicationController so it applies to all requests
  - Write tests verifying timezone application for users with a timezone set and UTC fallback for users without one
  - _Requirements: 8.2, 8.4, 8.5_

- [x] 5. Implement dual-root routing with dashboard and landing page
- [x] 5.1 Create the AuthenticatedConstraint for route-level authentication checks
  - Implement a routing constraint class that checks the signed session cookie against the sessions table
  - Return true when a valid session exists, false otherwise
  - Place the constraint in the appropriate application directory for routing components
  - _Requirements: 3.1, 4.1, 4.6_

- [x] 5.2 (P) Build the DashboardController and view
  - Create a controller with a show action that requires authentication (inherited default)
  - Set up the view to greet the user by name when a profile with a name exists
  - Display a prompt to complete the profile when no profile has been created yet
  - Ensure the dashboard serves as the post-authentication redirect target (the default root_url behavior)
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 5.3 (P) Build the PagesController and landing page view
  - Create a controller with a home action that allows unauthenticated access
  - Build the landing page view with a brief description of the application, a visible link to the login page, and a visible link to the registration page
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 5.4 Configure the dual-root routes
  - Declare the authenticated root pointing to the dashboard before the unauthenticated root pointing to the landing page in the routes file
  - Use the AuthenticatedConstraint to differentiate between authenticated and unauthenticated requests at the routing layer
  - Authenticated users visiting the root are routed to the dashboard; unauthenticated users see the landing page; this constraint also ensures authenticated users never reach the landing page (implicit redirect)
  - _Requirements: 3.1, 4.1, 4.6_

- [x] 5.5 Write controller tests for dashboard and landing page
  - Test that an authenticated user sees the dashboard at the root path with a personalized greeting
  - Test that the dashboard shows a profile completion prompt when no profile exists
  - Test that an unauthenticated user sees the landing page at the root path
  - Test that an unauthenticated user can access the landing page without being redirected to login
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [ ] 6. Build the application layout and responsive navigation
- [ ] 6.1 Create the responsive navigation partial
  - Build a navigation bar partial that displays on all authenticated pages
  - Include links to the dashboard and profile settings
  - Include a logout action
  - Show the authenticated user's name (from profile) or email in the navigation
  - Use conditional rendering to adjust content for authenticated versus unauthenticated states
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.6_

- [ ] 6.2 (P) Create the NavToggle Stimulus controller for mobile menu
  - Build a Stimulus controller that toggles the visibility of the mobile navigation menu
  - Use Stimulus targets and CSS class toggling for the hamburger menu behavior
  - Register the controller in the Stimulus application
  - _Requirements: 6.1, 6.5_

- [ ] 6.3 Update the application layout
  - Render the navigation partial in the application layout
  - Apply mobile-first responsive Tailwind CSS styling to the overall layout structure
  - Add appropriate conditional content for authenticated versus unauthenticated states
  - _Requirements: 6.5, 6.6_

- [ ] 7. Activate PWA capabilities
- [ ] 7.1 (P) Configure the PWA manifest and layout meta tags
  - Update the existing manifest template with the correct app name, standalone display mode, appropriate theme and background colors, and a full app description
  - Verify the existing icon entries (512x512 with regular and maskable purposes) are present
  - Uncomment or add the manifest link tag in the application layout head
  - Add PWA meta tags (theme-color) to the layout; verify that apple-mobile-web-app-capable and mobile-web-app-capable are already present
  - Uncomment the PWA manifest route
  - _Requirements: 2.1, 2.2, 2.3, 2.6, 2.7, 2.8_

- [ ] 7.2 (P) Implement the service worker with offline fallback
  - Update the existing service worker template to pre-cache an offline fallback page during the install event
  - Implement a fetch event listener that intercepts failed navigation requests and returns the cached offline page
  - Create a static offline HTML page in the public directory with a user-friendly offline message
  - Uncomment the service worker route
  - _Requirements: 2.4, 2.5, 2.7_

- [ ] 8. Enable SSL enforcement in production
  - Uncomment the assume_ssl and force_ssl configuration settings in the production environment config
  - Ensure the SSL options exclude the health check endpoint from SSL enforcement
  - _Requirements: 7.8_

- [ ] 9. Verify existing deployment infrastructure
  - Confirm the health check endpoint at /up returns HTTP 200
  - Confirm Solid Queue, Solid Cache, and Solid Cable are configured for production
  - Confirm encrypted credentials infrastructure is in place
  - Confirm the production Dockerfile exists and is suitable for container-based deployment
  - Confirm Propshaft serves assets with proper cache headers in production config
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

- [ ] 10. Integration testing for end-to-end flows
- [ ] 10.1 Write integration tests for the registration-to-dashboard flow
  - Test the complete flow: register a new account, get redirected to profile setup, create a profile, land on the dashboard with a personalized greeting
  - Test root path routing: unauthenticated request shows landing page, authenticated request shows dashboard
  - _Requirements: 1.1, 1.4, 3.1, 3.2, 3.5, 4.1, 5.2, 5.6_

- [ ]* 10.2 Write system tests for user-facing flows
  - Test the landing page displays the app description and has functional login and signup links
  - Test the registration form: fill in fields, submit, see the profile setup page
  - Test the dashboard displays a personalized greeting after login
  - Test responsive navigation: nav bar visible on desktop, hamburger toggle functional on mobile
  - _Requirements: 3.2, 4.2, 4.3, 4.4, 5.1, 5.2, 6.1, 6.5_
