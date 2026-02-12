# Turbo Frame Filtering Flow

## Overview

This document explains how the biology reports filtering feature works with Turbo Frames to provide a seamless, no-reload user experience.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Browser (Client)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │         biology_reports/index.html.erb                  │    │
│  │                                                          │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  Filter Form (GET request)                    │      │    │
│  │  │  data: { turbo_frame: "biology_reports_list" } │      │    │
│  │  │                                                │      │    │
│  │  │  [Date From] [Date To] [Lab Name]  [Filter]   │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  │                          │                               │    │
│  │                          │ Submit (via Turbo)            │    │
│  │                          ▼                               │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  <turbo-frame id="biology_reports_list">      │      │    │
│  │  │                                                │      │    │
│  │  │    ┌──────────────────────────────┐          │      │    │
│  │  │    │ _biology_reports_list.html.erb│          │      │    │
│  │  │    │                                │          │      │    │
│  │  │    │  • Report 1 (LabCorp)          │          │      │    │
│  │  │    │  • Report 2 (Quest)            │          │      │    │
│  │  │    │  • Report 3 (LabCorp West)     │ ◄─ Updates │    │    │
│  │  │    │                                │     only    │    │    │
│  │  │    └──────────────────────────────┘     this!  │    │    │
│  │  │                                                │      │    │
│  │  │  </turbo-frame>                                │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  │                                                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ GET /biology_reports?date_from=...&lab_name=...
                              │ Header: Turbo-Frame: biology_reports_list
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Rails Server (Backend)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │        BiologyReportsController#index                   │    │
│  │                                                          │    │
│  │  1. Scope to current user                               │    │
│  │     @biology_reports = Current.user.biology_reports     │    │
│  │                                                          │    │
│  │  2. Apply filters                                        │    │
│  │     .by_date_range(params[:date_from], params[:date_to])│    │
│  │     .by_lab_name(params[:lab_name])                     │    │
│  │                                                          │    │
│  │  3. Check request type                                   │    │
│  │     if turbo_frame_request?                             │    │
│  │       # Return partial only                             │    │
│  │       render partial: "biology_reports_list"            │    │
│  │     else                                                 │    │
│  │       # Return full page                                │    │
│  │       render :index                                      │    │
│  │                                                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │        BiologyReport Model Scopes                       │    │
│  │                                                          │    │
│  │  by_date_range(from, to):                               │    │
│  │    - Filter test_date >= from (if present)              │    │
│  │    - Filter test_date <= to (if present)                │    │
│  │                                                          │    │
│  │  by_lab_name(query):                                    │    │
│  │    - Case-insensitive LIKE match                        │    │
│  │    - SQL injection protected                            │    │
│  │                                                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTML Fragment Response
                              ▼
                    (Turbo replaces frame content)
```

## Request Flow

### 1. User Interacts with Filter Form

```html
<form action="/biology_reports" method="get" data-turbo-frame="biology_reports_list">
  <input type="date" name="date_from" value="2025-01-01">
  <input type="date" name="date_to" value="">
  <input type="text" name="lab_name" value="Quest">
  <button type="submit">Filter</button>
</form>
```

**Key Attributes**:
- `method="get"`: Preserves filter state in URL
- `data-turbo-frame="biology_reports_list"`: Tells Turbo where to update

### 2. Turbo Intercepts Form Submission

**Automatic Behavior**:
- Turbo intercepts the form submit
- Adds HTTP header: `Turbo-Frame: biology_reports_list`
- Sends GET request to `/biology_reports?date_from=2025-01-01&lab_name=Quest`
- No page reload!

### 3. Controller Detects Turbo Frame Request

```ruby
def index
  @biology_reports = Current.user.biology_reports.ordered
  @biology_reports = @biology_reports.by_date_range(params[:date_from], params[:date_to])
  @biology_reports = @biology_reports.by_lab_name(params[:lab_name])

  if turbo_frame_request?
    render partial: "biology_reports_list", locals: { biology_reports: @biology_reports }, layout: false
  end
  # else: render full page (default)
end
```

**Helper Method**:
```ruby
def turbo_frame_request?
  request.headers["Turbo-Frame"].present?
end
```

### 4. Model Applies Filters

```ruby
# Date range filter
scope :by_date_range, ->(from_date, to_date) {
  scope = all
  scope = scope.where("test_date >= ?", from_date) if from_date.present?
  scope = scope.where("test_date <= ?", to_date) if to_date.present?
  scope
}

# Lab name filter (case-insensitive, partial match)
scope :by_lab_name, ->(query) {
  return all if query.blank?
  sanitized_query = sanitize_sql_like(query)
  where("LOWER(lab_name) LIKE LOWER(?)", "%#{sanitized_query}%")
}
```

**SQL Generated** (example):
```sql
SELECT * FROM biology_reports
WHERE user_id = 1
  AND test_date >= '2025-01-01'
  AND LOWER(lab_name) LIKE LOWER('%quest%')
ORDER BY test_date DESC
```

### 5. Server Returns Partial HTML

```html
<!-- Only the list content, no layout -->
<div class="grid gap-4">
  <div class="bg-white rounded-lg shadow p-6">
    <h3>Quest Diagnostics</h3>
    <p>January 15, 2025</p>
  </div>
  <!-- Filtered results only -->
</div>
```

### 6. Turbo Updates Frame Content

**What Happens**:
- Turbo finds `<turbo-frame id="biology_reports_list">` in the page
- Replaces its content with the server response
- Updates browser URL to `/biology_reports?date_from=2025-01-01&lab_name=Quest`
- **No page reload! No layout re-render! No JavaScript needed!**

## User Experience

### Without Turbo Frames (Traditional)
1. User fills filter form
2. Click "Filter" → **Full page reload**
3. Server renders entire page
4. Browser replaces everything
5. **Slow, flickering, loses scroll position**

### With Turbo Frames (Modern)
1. User fills filter form
2. Click "Filter" → **No visible reload**
3. Server renders only the list partial
4. Turbo replaces just the list
5. **Fast, smooth, maintains context**

## Key Benefits

1. **Performance**: Only updates what changed
2. **UX**: No jarring page reloads
3. **Simplicity**: No JavaScript code needed
4. **SEO**: URL contains filter state
5. **Bookmarkable**: Users can bookmark filtered views
6. **Back Button**: Browser history works correctly

## Testing Strategy

### Unit Tests (Model)
```ruby
test "by_date_range scope filters by date range" do
  report1 = BiologyReport.create!(user: user, test_date: Date.new(2025, 1, 15))
  report2 = BiologyReport.create!(user: user, test_date: Date.new(2025, 2, 10))

  results = BiologyReport.by_date_range(Date.new(2025, 2, 1), Date.new(2025, 2, 28))

  assert_equal 1, results.count
  assert_includes results, report2
end
```

### Integration Tests (Controller)
```ruby
test "index should return turbo_frame for turbo_frame requests" do
  get biology_reports_url, headers: { "Turbo-Frame" => "biology_reports_list" }

  assert_response :success
  assert_no_match /<h1.*Biology Reports/, response.body # No layout
  assert_match /LabCorp/, response.body # Has content
end
```

### System Tests (End-to-End)
```ruby
test "filtering biology reports by date range without page reload" do
  visit biology_reports_path

  fill_in "From Date", with: "2025-01-01"
  click_button "Filter"

  # Verify Turbo Frame update (no full reload)
  assert_text "Quest Diagnostics"
  assert_no_text "December 20, 2024"
end
```

## Implementation Files

### Modified
- `app/controllers/biology_reports_controller.rb` - Filter logic and Turbo detection
- `app/controllers/application_controller.rb` - Helper method

### Existing (No Changes)
- `app/models/biology_report.rb` - Scopes already implemented
- `app/views/biology_reports/index.html.erb` - Turbo Frame already set up
- `app/views/biology_reports/_biology_reports_list.html.erb` - Partial already exists

### New
- `test/system/biology_reports_filtering_test.rb` - System tests

## Browser Network Tab

### Request
```
GET /biology_reports?date_from=2025-01-01&lab_name=Quest HTTP/1.1
Host: localhost:3000
Accept: text/html
Turbo-Frame: biology_reports_list  ← Key header!
```

### Response
```
HTTP/1.1 200 OK
Content-Type: text/html

<div class="grid gap-4">...</div>  ← Partial HTML only
```

## Conclusion

The Turbo Frame filtering implementation provides a modern, performant user experience without writing JavaScript. The server-side rendering approach maintains simplicity while delivering SPA-like interactivity.
