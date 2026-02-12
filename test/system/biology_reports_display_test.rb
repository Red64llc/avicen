require "application_system_test_case"

class BiologyReportsDisplayTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as_system(@user)
    @biology_report = biology_reports(:one)
  end

  test "show view displays report metadata correctly" do
    visit biology_report_path(@biology_report)

    # Verify report metadata is displayed
    assert_text "Biology Report"
    assert_text "Test Date"
    assert_text @biology_report.test_date.strftime("%B %d, %Y")

    if @biology_report.lab_name.present?
      assert_text "Laboratory"
      assert_text @biology_report.lab_name
    end

    if @biology_report.notes.present?
      assert_text "Notes"
      assert_text @biology_report.notes
    end
  end

  test "show view highlights out-of-range test results with color and icon" do
    # Create a biomarker and test results with out-of-range flag
    biomarker = biomarkers(:glucose)

    # Create an out-of-range test result
    out_of_range_result = @biology_report.test_results.create!(
      biomarker: biomarker,
      value: 150.0,  # Above normal range
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0,
      out_of_range: true
    )

    # Create an in-range test result
    normal_result = @biology_report.test_results.create!(
      biomarker: biomarkers(:hemoglobin),
      value: 14.5,  # Within normal range
      unit: "g/dL",
      ref_min: 13.5,
      ref_max: 17.5,
      out_of_range: false
    )

    visit biology_report_path(@biology_report)

    # Verify test results table exists
    assert_selector "table"
    assert_text "Biomarker"
    assert_text "Value"
    assert_text "Reference Range"
    assert_text "Status"

    # Verify out-of-range result has distinct visual treatment
    # Check for red background on row
    assert_selector "tr.bg-red-50", text: biomarker.name

    # Check for "Out of Range" badge with icon
    within("tr", text: biomarker.name) do
      assert_text "⚠ Out of Range"
      # Verify badge has red styling
      assert_selector "span.bg-red-100.text-red-800", text: "Out of Range"
    end

    # Verify normal result has green badge
    within("tr", text: biomarkers(:hemoglobin).name) do
      assert_text "✓ Normal"
      assert_selector "span.bg-green-100.text-green-800", text: "Normal"
      # Normal rows should not have red background
      assert_no_selector "tr.bg-red-50"
    end
  end

  test "show view displays attached document with view and download links" do
    # Attach a test document to the biology report
    @biology_report.document.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "test_lab_report.pdf")),
      filename: "test_lab_report.pdf",
      content_type: "application/pdf"
    )

    visit biology_report_path(@biology_report)

    # Verify document section is displayed
    assert_text "Attached Document"

    # Verify "View Document" link exists and opens in new tab
    assert_link "View Document", href: rails_blob_path(@biology_report.document, disposition: "inline")
    view_link = find_link("View Document")
    assert_equal "_blank", view_link[:target]

    # Verify "Download" link exists
    assert_link "Download", href: rails_blob_path(@biology_report.document, disposition: "attachment")
  end

  test "show view handles report without document attachment" do
    # Ensure no document is attached
    @biology_report.document.purge if @biology_report.document.attached?

    visit biology_report_path(@biology_report)

    # Verify document section is not displayed when no document attached
    assert_no_text "Attached Document"
    assert_no_link "View Document"
    assert_no_link "Download"
  end

  test "show view handles report without test results" do
    # Ensure no test results exist
    @biology_report.test_results.destroy_all

    visit biology_report_path(@biology_report)

    # Verify test results section exists but shows empty message
    assert_text "Test Results"
    assert_text "No test results yet"

    # Table should not be rendered when empty
    assert_no_selector "table"
  end

  test "form displays validation errors with proper styling" do
    visit new_biology_report_path

    # Submit form with missing required field (test_date)
    fill_in "Laboratory Name", with: "Test Lab"
    click_button "Create Report"

    # Verify validation error is displayed with red styling
    assert_selector ".bg-red-50.border-red-200.text-red-800", text: "prohibited this report from being saved"
    assert_text "Test date can't be blank"
  end

  test "form displays current document filename when editing report with attachment" do
    # Attach a document to the report
    @biology_report.document.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "test_lab_report.pdf")),
      filename: "original_report.pdf",
      content_type: "application/pdf"
    )

    visit edit_biology_report_path(@biology_report)

    # Verify current document filename is displayed
    assert_text "Current: original_report.pdf"
  end

  test "form accepts valid document file types" do
    visit new_biology_report_path

    # Verify file input accepts correct MIME types
    file_input = find("input[type='file']#biology_report_document")
    assert_equal "application/pdf,image/jpeg,image/png", file_input[:accept]
  end

  test "index view displays reports in reverse chronological order" do
    visit biology_reports_path

    # Get all report dates displayed
    report_dates = all(".bg-white.rounded-lg.shadow").map do |card|
      card.text
    end

    # Verify dates appear in reverse chronological order
    # (Most recent first)
    assert report_dates.join.match?(/Feb.*Jan.*Dec/m),
      "Reports should be displayed in reverse chronological order (newest first)"
  end

  test "index view displays test date, lab name, and notes for each report" do
    visit biology_reports_path

    biology_reports = @user.biology_reports.ordered

    biology_reports.each do |report|
      # Verify test date is displayed as a link
      assert_link report.test_date.strftime("%B %d, %Y"), href: biology_report_path(report)

      # Verify lab name is displayed if present
      if report.lab_name.present?
        assert_text "Laboratory: #{report.lab_name}"
      end

      # Verify notes are displayed if present
      if report.notes.present?
        assert_text report.notes
      end
    end
  end

  test "filter form has correct Turbo Frame target for partial updates" do
    visit biology_reports_path

    # Verify form has turbo_frame data attribute
    form = find("form[action='#{biology_reports_path}']")
    assert_equal "biology_reports_list", form["data-turbo-frame"]
  end

  test "test results table displays biomarker name, code, value, unit, and reference range" do
    biomarker = biomarkers(:glucose)
    test_result = @biology_report.test_results.create!(
      biomarker: biomarker,
      value: 95.0,
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0,
      out_of_range: false
    )

    visit biology_report_path(@biology_report)

    # Verify all test result data is displayed
    within("table") do
      # Biomarker name and code
      assert_text biomarker.name
      assert_text biomarker.code

      # Value with unit
      assert_text "95.0 mg/dL"

      # Reference range
      assert_text "70.0 - 100.0 mg/dL"

      # Status
      assert_text "✓ Normal"
    end
  end

  test "test results table handles missing reference range gracefully" do
    biomarker = biomarkers(:glucose)
    test_result = @biology_report.test_results.create!(
      biomarker: biomarker,
      value: 95.0,
      unit: "mg/dL",
      ref_min: nil,
      ref_max: nil,
      out_of_range: nil
    )

    visit biology_report_path(@biology_report)

    within("table tbody tr", text: biomarker.name) do
      # Reference range column should show N/A
      assert_text "N/A", count: 2  # Once in reference range column, once in status

      # Status should show N/A badge with gray styling
      assert_selector "span.bg-gray-100.text-gray-800", text: "N/A"
    end
  end
end
