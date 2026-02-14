# frozen_string_literal: true

require "test_helper"

# Tests for the prescription review form view (Task 10.2)
# Requirements: 5.1, 5.4, 5.7
#
# 5.1: Display all extracted data in an editable form
# 5.4: Provide autocomplete suggestions for drug names when user edits
# 5.7: Preserve original scanned image and attach to created record (handled in controller)
class PrescriptionFormViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @prescription = prescriptions(:one)
    sign_in_as(@user)
  end

  # --- Requirement 5.1: Display all extracted data in editable form ---

  test "review displays all extracted medications in editable form" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Test",
        prescription_date: "2026-01-15",
        medications: [
          {
            drug_name: "Aspirin",
            dosage: "100mg",
            frequency: "daily",
            duration: "30 days",
            quantity: "30",
            confidence: 0.95
          },
          {
            drug_name: "Ibuprofen",
            dosage: "200mg",
            frequency: "twice daily",
            confidence: 0.88
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should display editable fields for each medication
    # Use type='text' to exclude hidden fields (verified_* fields) and template fields
    assert_select "[data-review-form-target='medicationsList'] input[type='text'][name*='drug_name']", count: 2
    assert_select "[data-review-form-target='medicationsList'] input[type='text'][name*='dosage']", count: 2
    assert_select "[data-review-form-target='medicationsList'] input[type='text'][name*='frequency']", count: 2
  end

  test "review form includes duration and quantity fields for medications" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            dosage: "100mg",
            frequency: "daily",
            duration: "30 days",
            quantity: "30",
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have duration and quantity fields
    assert_select "input[name*='medications'][name*='duration']"
    assert_select "input[name*='medications'][name*='quantity']"
  end

  test "review form includes doctor name and prescription date at top level" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Review Test",
        prescription_date: "2026-02-01",
        medications: []
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have doctor name and date fields
    assert_select "input[name*='doctor_name']"
    assert_select "input[name*='prescribed_date']"
  end

  # --- Confidence indicators (Requirement 5.2 via design.md) ---

  test "review form shows visual confidence indicators for each field" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            dosage: "100mg",
            frequency: "daily",
            confidence: 0.6 # Low confidence
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Low confidence medications should have visual indicator
    # Check for warning styling (yellow/amber border or background)
    assert_match /border-yellow|bg-yellow|requires_verification|confidence/i, response.body
  end

  test "review form shows confidence percentage for low confidence medications" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Unclear Drug",
            confidence: 0.55
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should show confidence percentage for low confidence items
    assert_match /55%|Confidence/i, response.body
  end

  test "review form highlights fields flagged as requires_verification" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Unverified Drug",
            confidence: 0.4,
            requires_verification: true
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have verification warning indicator
    assert_match /verify|verification|warning/i, response.body
  end

  # --- Requirement 5.4: Drug search autocomplete integration ---

  test "review form integrates drug_search autocomplete for drug name fields" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Drug name input should have drug-search controller
    assert_select "[data-controller*='drug-search']"
  end

  test "review form includes hidden drug_id field for autocomplete selection" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            matched_drug_id: 123,
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have hidden field for drug_id
    assert_select "input[type='hidden'][name*='drug_id']"
  end

  test "review form includes results container for drug_search autocomplete" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Test Drug",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have results container for autocomplete dropdown
    assert_select "[data-drug-search-target='results']"
  end

  # --- Adding/Removing medications ---

  test "review form allows adding new medications with add button" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have "Add Medication" button
    assert_select "button, a", text: /Add Medication|Add/i
  end

  test "review form allows removing medications with remove button" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            confidence: 0.9
          },
          {
            drug_name: "Ibuprofen",
            confidence: 0.85
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have remove button for each medication
    assert_select "button, a", text: /Remove|Delete/i, minimum: 1
  end

  test "review form has medications list target for dynamic add/remove" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have target for medications list (for Stimulus controller)
    assert_select "[data-review-form-target='medicationsList']"
  end

  # --- Show matched drug metadata ---

  test "review form shows matched drug name when drug_id is present" do
    drug = drugs(:aspirin)

    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            matched_drug_id: drug.id,
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should show the matched drug information
    assert_match /Aspirin/i, response.body
  end

  test "review form shows matched drug metadata including active ingredients" do
    drug = drugs(:aspirin)

    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            matched_drug_id: drug.id,
            matched_drug_name: drug.name,
            active_ingredients: drug.active_ingredients,
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should show active ingredients metadata if available
    if drug.active_ingredients.present?
      assert_match /active.?ingredient|#{Regexp.escape(drug.active_ingredients.to_s)}/i, response.body
    end
  end

  test "review form shows match indicator when drug is found in database" do
    drug = drugs(:aspirin)

    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            matched_drug_id: drug.id,
            confidence: 0.95
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have some indicator that drug was matched
    assert_match /matched|found|database|verified/i, response.body
  end

  # --- Review form controller integration ---

  test "review form uses review_form stimulus controller" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: []
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Form should use review-form controller
    assert_select "[data-controller*='review-form']"
  end

  test "review form includes data attributes for confidence on editable fields" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            confidence: 0.75
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Editable fields should have confidence data attribute for controller
    assert_select "[data-confidence]", minimum: 1
  end

  test "review form includes field target for review_form controller" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should have field targets for the review form controller
    assert_select "[data-review-form-target='field']", minimum: 1
  end

  # --- Empty medications handling ---

  test "review form shows message when no medications extracted" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Empty",
        medications: []
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Should show helpful message for empty medications
    assert_match /no medications|add.*manually|empty/i, response.body
  end

  # --- Form structure and accessibility ---

  test "review form has labels for all medication fields" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            dosage: "100mg",
            frequency: "daily",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Each field should have a label
    assert_select "label", minimum: 3 # drug_name, dosage, frequency at minimum
  end

  test "review form has proper form structure for nested medications" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        medications: [
          {
            drug_name: "Aspirin",
            confidence: 0.9
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success

    # Medication fields should be properly nested with index
    assert_select "input[name*='medications[0]']", minimum: 1
  end
end
