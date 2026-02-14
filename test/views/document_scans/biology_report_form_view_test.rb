# frozen_string_literal: true

require "test_helper"

# Tests for the biology report review form view (Task 10.3)
# Requirements: 5.1, 5.4, 5.7
#
# 5.1: Display all extracted data in an editable form
# 5.4: Provide autocomplete suggestions for biomarker names when user edits
# 5.7: Preserve original scanned image and attach to created record (handled in controller)
class BiologyReportFormViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @biology_report = biology_reports(:one)
    sign_in_as(@user)
  end

  # --- Requirement 5.1: Display all extracted data in editable form ---

  test "review displays all extracted test results in editable form" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "LabCorp",
        test_date: "2026-01-15",
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            unit: "mg/dL",
            reference_min: 70.0,
            reference_max: 100.0,
            confidence: 0.95
          },
          {
            biomarker_name: "Hemoglobin",
            value: "14.5",
            unit: "g/dL",
            confidence: 0.88
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should display editable fields for each test result
    assert_select "input[name*='test_results'][name*='biomarker_name']", count: 2
    assert_select "input[name*='test_results'][name*='value']", count: 2
    assert_select "input[name*='test_results'][name*='unit']", count: 2
  end

  test "review form includes reference min and max fields for test results" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            unit: "mg/dL",
            reference_min: 70.0,
            reference_max: 100.0,
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have reference min and max fields
    assert_select "input[name*='test_results'][name*='ref_min']"
    assert_select "input[name*='test_results'][name*='ref_max']"
  end

  test "review form includes lab name and test date at top level" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Quest Diagnostics",
        test_date: "2026-02-01",
        test_results: []
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have lab name and test date fields
    assert_select "input[name*='lab_name']"
    assert_select "input[name*='test_date']"
  end

  # --- Confidence indicators (Requirement 5.2 via design.md) ---

  test "review form shows visual confidence indicators for each field" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            confidence: 0.6 # Low confidence
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Low confidence test results should have visual indicator
    # Check for warning styling (yellow/amber border or background)
    assert_match /border-yellow|bg-yellow|requires_verification|confidence/i, response.body
  end

  test "review form shows confidence percentage for low confidence test results" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Unclear Biomarker",
            value: "123",
            confidence: 0.55
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should show confidence percentage for low confidence items
    assert_match /55%|Confidence/i, response.body
  end

  test "review form highlights fields flagged as requires_verification" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Unverified Biomarker",
            value: "99",
            confidence: 0.4,
            requires_verification: true
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have verification warning indicator
    assert_match /verify|verification|warning/i, response.body
  end

  # --- Out-of-range value highlighting ---

  test "review form highlights out-of-range values with visual indicator" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "150",
            unit: "mg/dL",
            reference_min: 70.0,
            reference_max: 100.0,
            out_of_range: true,
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Out-of-range values should have red/danger visual indicator
    assert_match /border-red|bg-red|out.?of.?range|outside.?reference/i, response.body
  end

  test "review form shows warning icon for out-of-range values" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Hemoglobin",
            value: "8.0",
            unit: "g/dL",
            reference_min: 13.5,
            reference_max: 17.5,
            out_of_range: true,
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have some kind of warning/error icon or text
    assert_match /outside.?reference|out.?of.?range|svg|icon/i, response.body
  end

  # --- Requirement 5.4: Biomarker search autocomplete integration ---

  test "review form integrates biomarker_search autocomplete for biomarker name fields" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Biomarker name input should have biomarker-search controller
    assert_select "[data-controller*='biomarker-search']"
  end

  test "review form includes hidden biomarker_id field for autocomplete selection" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            matched_biomarker_id: 123,
            value: "95",
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have hidden field for biomarker_id
    assert_select "input[type='hidden'][name*='biomarker_id']"
  end

  test "review form includes results container for biomarker_search autocomplete" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "TSH",
            value: "2.5",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have results container for autocomplete dropdown
    assert_select "[data-biomarker-search-target='results']"
  end

  # --- Adding/Removing test results ---

  test "review form allows adding new test results with add button" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have "Add Test Result" button
    assert_select "button, a", text: /Add Test|Add Result|Add/i
  end

  test "review form allows removing test results with remove button" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            confidence: 0.9
          },
          {
            biomarker_name: "Hemoglobin",
            value: "14.5",
            confidence: 0.85
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have remove button for each test result
    assert_select "button, a", text: /Remove|Delete/i, minimum: 1
  end

  test "review form has test results list target for dynamic add/remove" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have target for test results list (for Stimulus controller)
    assert_select "[data-review-form-target='testResultsList']"
  end

  # --- Show matched biomarker metadata ---

  test "review form shows matched biomarker name when biomarker_id is present" do
    biomarker = biomarkers(:glucose)

    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            matched_biomarker_id: biomarker.id,
            value: "95",
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should show the matched biomarker information
    assert_match /Glucose/i, response.body
  end

  test "review form shows match indicator when biomarker is found in database" do
    biomarker = biomarkers(:glucose)

    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            matched_biomarker_id: biomarker.id,
            value: "95",
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have some indicator that biomarker was matched
    assert_match /matched|found|database|verified/i, response.body
  end

  # --- Review form controller integration ---

  test "review form uses review_form stimulus controller" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: []
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Form should use review-form controller
    assert_select "[data-controller*='review-form']"
  end

  test "review form includes data attributes for confidence on editable fields" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            confidence: 0.75
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Editable fields should have confidence data attribute for controller
    assert_select "[data-confidence]", minimum: 1
  end

  test "review form includes field target for review_form controller" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have field targets for the review form controller
    assert_select "[data-review-form-target='field']", minimum: 1
  end

  # --- Empty test results handling ---

  test "review form shows message when no test results extracted" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Empty Lab",
        test_results: []
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should show helpful message for empty test results
    assert_match /no test results|add.*manually|empty/i, response.body
  end

  # --- Form structure and accessibility ---

  test "review form has labels for all test result fields" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            unit: "mg/dL",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Each field should have a label
    assert_select "label", minimum: 3 # biomarker_name, value, unit at minimum
  end

  test "review form has proper form structure for nested test results" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Test result fields should be properly nested with index
    assert_select "input[name*='test_results[0]']", minimum: 1
  end

  # --- Template for adding new test results ---

  test "review form has template for adding new test results dynamically" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: []
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have a template element for new test results
    assert_select "template[data-review-form-target='testResultTemplate']"
  end

  # --- Biomarker search autocomplete auto-fill targets ---

  test "review form includes auto-fill targets for biomarker search" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            unit: "mg/dL",
            reference_min: 70.0,
            reference_max: 100.0,
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success

    # Should have auto-fill targets for unit, ref_min, ref_max
    assert_select "[data-biomarker-search-target='unitField']"
    assert_select "[data-biomarker-search-target='refMinField']"
    assert_select "[data-biomarker-search-target='refMaxField']"
  end
end
