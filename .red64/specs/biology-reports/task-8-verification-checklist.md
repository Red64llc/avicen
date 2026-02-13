# Task 8 Verification Checklist

## Pre-Verification Setup

Due to Ruby environment limitations, the following verification steps should be performed when Ruby 3.4.8 is available:

### 1. Environment Setup
```bash
# Ensure Ruby is installed
ruby --version  # Should show 3.4.8

# Install dependencies
bundle install

# Setup database
bin/rails db:migrate
bin/rails db:seed  # Ensure biomarker seed data is loaded
```

### 2. Run Tests

#### Unit Tests (BiomarkersController)
```bash
bin/rails test test/controllers/biomarkers_controller_test.rb
```

Expected results:
- ✅ should get index when authenticated
- ✅ should show biomarkers with test result counts
- ✅ should order biomarkers alphabetically by name
- ✅ should only show biomarkers with test results for current user
- ✅ should link to biomarker trend page
- ✅ should redirect to login when not authenticated

#### System Tests (Filter Form)
```bash
bin/rails test:system test/system/biology_report_filtering_test.rb
```

Expected results:
- ✅ filter form auto-submits on input change with debouncing
- ✅ date filters auto-submit via Turbo Frame
- ✅ multiple rapid filter changes are debounced

### 3. Manual UI Verification

#### Start Development Server
```bash
bin/rails server
```

Navigate to: http://localhost:3000

#### Task 8.1: Biomarker Index View

1. **Access Biomarker Index**
   - Log in as a test user
   - Navigate to `/biology_reports`
   - Click "View Biomarker Trends" button
   - OR navigate directly to `/biomarkers`

2. **Verify Display**
   - [ ] Page shows "Biomarker Trends" heading
   - [ ] Biomarker cards display in grid layout (responsive)
   - [ ] Each card shows:
     - Biomarker name (e.g., "Glucose")
     - Biomarker code (e.g., "2345-7")
     - Test result count badge (blue circle with number)
     - "View trend" link with arrow icon
   - [ ] Cards are ordered alphabetically by biomarker name
   - [ ] Only biomarkers with test results for current user are shown

3. **Verify Empty State**
   - Log in as a user with no test results
   - Navigate to `/biomarkers`
   - [ ] Shows empty state message: "No Biomarkers Yet"
   - [ ] Shows helpful text about creating first report
   - [ ] Shows "Create Your First Report" button linking to new biology report

4. **Verify Navigation**
   - Click on a biomarker card
   - [ ] Navigates to biomarker trend page (`/biomarker_trends/:id`)
   - [ ] Trend chart displays correctly
   - Click "Back to Reports" button
   - [ ] Returns to biology reports index

5. **Verify User Scoping**
   - Log in as User A with test results
   - Note which biomarkers are displayed
   - Log out and log in as User B
   - [ ] User B sees only their own biomarkers, not User A's

6. **Verify Count Accuracy**
   - For a biomarker with 1 test result:
     - [ ] Shows "1 test result" (singular)
   - For a biomarker with multiple test results:
     - [ ] Shows "X test results" (plural)
   - [ ] Count matches actual number of test results in database

#### Task 8.2: Filter-Form Stimulus Controller

1. **Verify Auto-Submit on Text Input**
   - Navigate to `/biology_reports`
   - Open browser DevTools → Network tab
   - Clear network log
   - Type slowly in "Laboratory" field: "Q" → "u" → "e" → "s" → "t"
   - Wait 500ms after last keystroke
   - [ ] Only ONE network request is made (debounced)
   - [ ] Request is made ~300ms after last keystroke
   - [ ] Turbo Frame update occurs (no full page reload)
   - [ ] URL query parameters update: `?lab_name=Quest`
   - [ ] Biology reports list updates without page refresh

2. **Verify Immediate Submit on Date Change**
   - Clear network log
   - Click on "From Date" field
   - Select a date
   - [ ] Network request fires IMMEDIATELY (no debounce)
   - [ ] Turbo Frame updates with filtered results
   - [ ] URL includes `?date_from=YYYY-MM-DD`

3. **Verify Rapid Typing Debounce**
   - Clear network log
   - Rapidly type "Laboratory" (as fast as possible)
   - [ ] Observe that requests are NOT fired during typing
   - [ ] After 300ms of no input, ONE request is fired
   - [ ] Reports list updates with final filter value

4. **Verify Multiple Filter Interaction**
   - Set "From Date" to 2024-01-01
   - [ ] List updates immediately
   - Type "Quest" in Laboratory field
   - [ ] After debounce, list updates again
   - Set "To Date" to 2024-12-31
   - [ ] List updates immediately
   - [ ] URL shows all filters: `?date_from=2024-01-01&date_to=2024-12-31&lab_name=Quest`

5. **Verify Clear Filters**
   - Apply multiple filters
   - Click "Clear" link
   - [ ] All filters are removed
   - [ ] URL returns to `/biology_reports` (no query params)
   - [ ] Full list of reports displays

6. **Verify Turbo Frame Behavior**
   - Apply a filter
   - [ ] Page title remains "Biology Reports" (no full reload)
   - [ ] Header and filter form remain intact
   - [ ] Only the reports list section updates
   - [ ] Browser back button works correctly

7. **Verify Accessibility**
   - [ ] Form labels are properly associated with inputs
   - [ ] Keyboard navigation works (Tab through form fields)
   - [ ] Enter key submits form
   - [ ] Screen reader announces filter updates

### 4. Code Quality Checks

#### Linting (RuboCop)
```bash
bundle exec rubocop app/controllers/biomarkers_controller.rb
bundle exec rubocop app/views/biomarkers/
```

Expected: No offenses detected

#### JavaScript Syntax Check
```bash
# In browser console or via Node.js
node --check app/javascript/controllers/filter_form_controller.js
```

Expected: No syntax errors

#### Security Check (Brakeman)
```bash
bundle exec brakeman -q
```

Expected: No new security warnings related to Task 8 code

### 5. Performance Verification

#### Database Query Efficiency
```bash
# Start Rails console
bin/rails console

# Test the biomarker query
user = User.first
biomarkers = Biomarker
  .joins(:test_results)
  .joins("INNER JOIN biology_reports ON biology_reports.id = test_results.biology_report_id")
  .where(biology_reports: { user: user })
  .select("biomarkers.*, COUNT(test_results.id) AS test_results_count")
  .group("biomarkers.id")
  .order("biomarkers.name ASC")

# Check SQL query
puts biomarkers.to_sql

# Verify single query (no N+1)
ActiveRecord::Base.logger = Logger.new(STDOUT)
biomarkers.load
```

Expected:
- [ ] Single SQL query with joins
- [ ] No N+1 queries
- [ ] Query includes COUNT aggregation
- [ ] Results ordered by biomarker name

#### Debounce Timing Verification
- In browser DevTools → Network tab
- Type rapidly in lab name field
- Measure time between last keystroke and network request
- [ ] Request fires ~300ms after last input
- [ ] Multiple rapid inputs are coalesced

### 6. Cross-Browser Testing

Test in:
- [ ] Chrome/Chromium (latest)
- [ ] Firefox (latest)
- [ ] Safari (if available)

Verify:
- [ ] Debouncing works correctly
- [ ] Turbo Frame updates work
- [ ] Layout is responsive
- [ ] No JavaScript console errors

### 7. Mobile Responsiveness

Test on mobile viewport (DevTools → Device Toolbar):
- [ ] Biomarker cards stack vertically on small screens
- [ ] Grid shows 2 columns on medium screens
- [ ] Grid shows 3 columns on large screens
- [ ] Filter form inputs stack vertically on mobile
- [ ] Touch interactions work correctly

## Post-Verification Actions

If all checks pass:
- ✅ Mark tasks 8.1 and 8.2 as complete
- ✅ Update task tracking in tasks.md (handled by orchestrator)
- ✅ Document any edge cases discovered
- ✅ Consider additional optimizations if needed

If issues are found:
- Document the issue
- Fix the implementation
- Re-run tests
- Update verification checklist

## Notes

- This checklist assumes test data is properly seeded (users, biology reports, test results, biomarkers)
- Some manual verification is required due to the interactive nature of the Stimulus controller
- Performance metrics should be measured with realistic data volume (50+ biology reports, 10+ biomarkers)
