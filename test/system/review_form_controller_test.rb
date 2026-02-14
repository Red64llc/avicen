require "application_system_test_case"

# System tests for the review_form_controller.js Stimulus controller.
# Tests verify:
#   - Controller connects and initializes with correct state
#   - Low confidence fields (< 0.8) are highlighted visually
#   - Editing a field marks it as user-verified
#   - Hidden fields track verification state for form submission
#   - Multiple fields can be tracked independently
#   - Medications can be added dynamically (Task 10.2)
#   - Medications can be removed dynamically (Task 10.2)
#   - Test results can be added dynamically (Task 10.3)
#   - Test results can be removed dynamically (Task 10.3)
#
# Requirements: 5.1, 5.2, 5.3, 5.4, 5.7, 6.4
class ReviewFormControllerTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "review form controller connects and initializes" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    # Verify the controller element exists with proper data attributes
    assert_selector "[data-controller='review-form']"

    # Wait for Stimulus controller to be connected
    wait_for_stimulus_controller("review-form")

    # Check via JavaScript that controller is connected
    connected = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='review-form']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "review-form");
        return controller !== null;
      })()
    JS

    assert connected, "Review form controller should be connected"
  end

  test "controller defines required targets" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Verify targets exist
    assert_selector "[data-review-form-target='field']"
    assert_selector "[data-review-form-target='confidence']"
    assert_selector "[data-review-form-target='submitButton']"
    assert_selector "[data-review-form-target='verifiedInput']", visible: :all
  end

  test "low confidence fields are highlighted on connect" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Field with confidence 0.6 (below 0.8 threshold) should be highlighted
    low_confidence_field = find("[data-review-form-target='field'][data-confidence='0.6']")
    assert low_confidence_field[:class].include?("ring-amber-500") || low_confidence_field[:class].include?("border-amber-500"),
           "Low confidence field should have warning highlight"
  end

  test "high confidence fields are not highlighted" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Field with confidence 0.95 (above 0.8 threshold) should NOT be highlighted with warning
    high_confidence_field = find("[data-review-form-target='field'][data-confidence='0.95']")
    assert_not high_confidence_field[:class].include?("ring-amber-500"),
               "High confidence field should not have warning highlight"
    assert_not high_confidence_field[:class].include?("border-amber-500"),
               "High confidence field should not have warning border"
  end

  test "confidence threshold value is configurable" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Check default threshold is 0.8
    threshold = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='review-form']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "review-form");
        return controller ? controller.confidenceThresholdValue : null;
      })()
    JS

    assert_equal 0.8, threshold, "Default confidence threshold should be 0.8"
  end

  test "editing a field marks it as verified" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Find the low confidence field and its associated hidden verified input
    field = find("[data-review-form-target='field'][data-field-name='drug_name']")
    verified_input = find("[data-review-form-target='verifiedInput'][data-field-name='drug_name']", visible: :all)

    # Initially should not be verified
    assert_equal "", verified_input.value, "Field should not be verified initially"

    # Edit the field
    field.set("Edited Drug Name")

    # Trigger input event (in case set doesn't trigger it)
    page.execute_script(<<~JS)
      (function() {
        const field = document.querySelector("[data-review-form-target='field'][data-field-name='drug_name']");
        field.dispatchEvent(new Event('input', { bubbles: true }));
      })()
    JS

    # Hidden input should now indicate verified
    sleep 0.2 # Allow for event processing
    assert_equal "true", verified_input.value, "Field should be marked as verified after editing"
  end

  test "editing a field removes low confidence highlight" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Find the low confidence field
    field = find("[data-review-form-target='field'][data-confidence='0.6']")

    # Verify it has the warning highlight initially
    assert field[:class].include?("ring-amber-500") || field[:class].include?("border-amber-500"),
           "Low confidence field should have warning highlight initially"

    # Edit the field
    field.set("Verified Value")

    # Trigger input event
    page.execute_script(<<~JS)
      (function() {
        const field = document.querySelector("[data-review-form-target='field'][data-confidence='0.6']");
        field.dispatchEvent(new Event('input', { bubbles: true }));
      })()
    JS

    sleep 0.2

    # Warning highlight should be removed after user verification
    field_updated = find("[data-review-form-target='field'][data-confidence='0.6']")
    assert_not field_updated[:class].include?("ring-amber-500"),
               "Warning highlight should be removed after user edits field"
  end

  test "multiple fields can be independently verified" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Find two different fields
    field1 = find("[data-review-form-target='field'][data-field-name='drug_name']")
    field2 = find("[data-review-form-target='field'][data-field-name='dosage']")
    verified1 = find("[data-review-form-target='verifiedInput'][data-field-name='drug_name']", visible: :all)
    verified2 = find("[data-review-form-target='verifiedInput'][data-field-name='dosage']", visible: :all)

    # Edit only first field
    field1.set("New Drug")
    page.execute_script(<<~JS)
      (function() {
        const field = document.querySelector("[data-review-form-target='field'][data-field-name='drug_name']");
        field.dispatchEvent(new Event('input', { bubbles: true }));
      })()
    JS

    sleep 0.2

    # First field should be verified, second should not
    assert_equal "true", verified1.value, "First field should be verified"
    assert_equal "", verified2.value, "Second field should not be verified yet"
  end

  test "verifiedFields tracks all verified field names" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Edit a field
    field = find("[data-review-form-target='field'][data-field-name='drug_name']")
    field.set("Test Drug")
    page.execute_script(<<~JS)
      (function() {
        const field = document.querySelector("[data-review-form-target='field'][data-field-name='drug_name']");
        field.dispatchEvent(new Event('input', { bubbles: true }));
      })()
    JS

    sleep 0.2

    # Check verifiedFields set via JavaScript
    verified_fields = page.evaluate_script(<<~JS)
      (function() {
        const element = document.querySelector("[data-controller='review-form']");
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "review-form");
        return controller ? Array.from(controller.verifiedFields) : null;
      })()
    JS

    assert_includes verified_fields, "drug_name", "verifiedFields should include edited field name"
  end

  test "confidence indicator displays confidence value visually" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Confidence indicators should exist
    confidence_indicators = all("[data-review-form-target='confidence']")
    assert confidence_indicators.length > 0, "Should have confidence indicators"

    # Check that indicators display confidence information
    confidence_indicator = find("[data-review-form-target='confidence'][data-confidence='0.6']")
    assert confidence_indicator.text.include?("60%") || confidence_indicator[:class].present?,
           "Confidence indicator should display confidence level"
  end

  test "highlightLowConfidenceFields is called on connect" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Verify highlighting was applied by checking that low confidence fields have the highlight class
    highlighted_fields = all("[data-review-form-target='field'].ring-amber-500, [data-review-form-target='field'].border-amber-500")
    assert highlighted_fields.length > 0, "Low confidence fields should be highlighted after connect"
  end

  test "field blur event also marks field as verified" do
    sign_in_as_system(@user)
    visit document_scans_review_form_test_path

    wait_for_stimulus_controller("review-form")

    # Find field and its verified input
    verified_input = find("[data-review-form-target='verifiedInput'][data-field-name='drug_name']", visible: :all)

    # Initially not verified
    assert_equal "", verified_input.value

    # Trigger blur on the field (simulating user focus then blur after editing)
    page.execute_script(<<~JS)
      (function() {
        const field = document.querySelector("[data-review-form-target='field'][data-field-name='drug_name']");
        // Simulate user editing
        field.value = "New Value";
        // Store original value to detect change
        field.dataset.originalValue = field.dataset.originalValue || "";
        field.dispatchEvent(new Event('blur', { bubbles: true }));
      })()
    JS

    sleep 0.2

    # Should be marked as verified after blur (if value changed)
    assert_equal "true", verified_input.value, "Field should be marked as verified after blur with changed value"
  end

  # --- Task 10.2: Medication Add/Remove Tests (Requirements 5.1, 5.4) ---

  test "controller defines medication-related targets" do
    sign_in_as_system(@user)

    # Create a prescription with extracted data for testing
    prescription = prescriptions(:one)
    prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Test",
        prescription_date: "2026-01-15",
        medications: [
          { drug_name: "Test Drug", dosage: "100mg", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(prescription, record_type: "prescription")

    wait_for_stimulus_controller("review-form")

    # Verify medication-related targets exist
    assert_selector "[data-review-form-target='medicationsList']"
    assert_selector "[data-review-form-target='medicationEntry']"
    assert_selector "template[data-review-form-target='medicationTemplate']", visible: :all
  end

  test "add medication button creates new medication entry" do
    sign_in_as_system(@user)

    prescription = prescriptions(:one)
    prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Test",
        medications: [
          { drug_name: "Initial Drug", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(prescription, record_type: "prescription")

    wait_for_stimulus_controller("review-form")

    # Count initial medication entries
    initial_count = all("[data-review-form-target='medicationEntry']").count
    assert_equal 1, initial_count, "Should have 1 medication initially"

    # Click add medication button
    find("button", text: /Add Medication/i).click

    sleep 0.3 # Allow for DOM update

    # Verify new medication entry was added
    new_count = all("[data-review-form-target='medicationEntry']").count
    assert_equal 2, new_count, "Should have 2 medications after adding"
  end

  test "add medication button works when no medications exist" do
    sign_in_as_system(@user)

    prescription = prescriptions(:one)
    prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Empty",
        medications: []
      }
    )

    visit review_document_scan_path(prescription, record_type: "prescription")

    wait_for_stimulus_controller("review-form")

    # Should show empty message initially
    assert_text "No medications were extracted"

    # Click add medication button
    find("button", text: /Add Medication/i).click

    sleep 0.3

    # Empty message should be removed and medication entry should exist
    assert_no_text "No medications were extracted"
    assert_selector "[data-review-form-target='medicationEntry']"
  end

  test "remove medication button removes medication entry" do
    sign_in_as_system(@user)

    prescription = prescriptions(:one)
    prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Test",
        medications: [
          { drug_name: "Drug 1", confidence: 0.9 },
          { drug_name: "Drug 2", confidence: 0.85 }
        ]
      }
    )

    visit review_document_scan_path(prescription, record_type: "prescription")

    wait_for_stimulus_controller("review-form")

    # Count initial medication entries
    initial_count = all("[data-review-form-target='medicationEntry']").count
    assert_equal 2, initial_count, "Should have 2 medications initially"

    # Click remove button on first medication
    first_entry = find("[data-review-form-target='medicationEntry']", match: :first)
    within(first_entry) do
      find("button[data-action*='removeMedication']").click
    end

    sleep 0.4 # Allow for animation and removal

    # Verify medication was removed
    new_count = all("[data-review-form-target='medicationEntry']").count
    assert_equal 1, new_count, "Should have 1 medication after removal"
  end

  test "removing all medications shows empty message" do
    sign_in_as_system(@user)

    prescription = prescriptions(:one)
    prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Test",
        medications: [
          { drug_name: "Only Drug", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(prescription, record_type: "prescription")

    wait_for_stimulus_controller("review-form")

    # Remove the only medication
    entry = find("[data-review-form-target='medicationEntry']")
    within(entry) do
      find("button[data-action*='removeMedication']").click
    end

    sleep 0.4

    # Empty message should appear
    assert_text "No medications were extracted"
    assert_selector ".empty-medications-message"
  end

  test "new medication entry has correct field names with unique index" do
    sign_in_as_system(@user)

    prescription = prescriptions(:one)
    prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Test",
        medications: [
          { drug_name: "Existing Drug", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(prescription, record_type: "prescription")

    wait_for_stimulus_controller("review-form")

    # Add a new medication
    find("button", text: /Add Medication/i).click
    sleep 0.3

    # Find the new entry (should have index 1)
    new_entry = find("[data-review-form-target='medicationEntry'][data-medication-index='1']")

    # Verify field names include the correct index
    within(new_entry) do
      assert_selector "input[name*='medications[1][drug_name]']"
      assert_selector "input[name*='medications[1][dosage]']"
      assert_selector "input[name*='medications[1][frequency]']"
    end
  end

  test "new medication focuses first input after addition" do
    sign_in_as_system(@user)

    prescription = prescriptions(:one)
    prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Test",
        medications: [
          { drug_name: "Existing Drug", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(prescription, record_type: "prescription")

    wait_for_stimulus_controller("review-form")

    # Add a new medication
    find("button", text: /Add Medication/i).click
    sleep 0.3

    # Check that the new entry's first input is focused
    focused_element = page.evaluate_script("document.activeElement.name")
    assert_match(/medications\[1\]/, focused_element, "New medication's first input should be focused")
  end

  # --- Task 10.3: Test Result Add/Remove Tests (Requirements 5.1, 5.4, 5.7) ---

  test "controller defines test result-related targets" do
    sign_in_as_system(@user)

    # Create a biology report with extracted data for testing
    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_date: "2026-01-15",
        test_results: [
          { biomarker_name: "Glucose", value: "95", unit: "mg/dL", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Verify test result-related targets exist
    assert_selector "[data-review-form-target='testResultsList']"
    assert_selector "[data-review-form-target='testResultEntry']"
    assert_selector "template[data-review-form-target='testResultTemplate']", visible: :all
  end

  test "add test result button creates new test result entry" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [
          { biomarker_name: "Glucose", value: "95", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Count initial test result entries
    initial_count = all("[data-review-form-target='testResultEntry']").count
    assert_equal 1, initial_count, "Should have 1 test result initially"

    # Click add test result button
    find("button", text: /Add Test Result/i).click

    sleep 0.3 # Allow for DOM update

    # Verify new test result entry was added
    new_count = all("[data-review-form-target='testResultEntry']").count
    assert_equal 2, new_count, "Should have 2 test results after adding"
  end

  test "add test result button works when no test results exist" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Empty Lab",
        test_results: []
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Should show empty message initially
    assert_text "No test results were extracted"

    # Click add test result button
    find("button", text: /Add Test Result/i).click

    sleep 0.3

    # Empty message should be removed and test result entry should exist
    assert_no_text "No test results were extracted"
    assert_selector "[data-review-form-target='testResultEntry']"
  end

  test "remove test result button removes test result entry" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [
          { biomarker_name: "Glucose", value: "95", confidence: 0.9 },
          { biomarker_name: "Hemoglobin", value: "14.5", confidence: 0.85 }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Count initial test result entries
    initial_count = all("[data-review-form-target='testResultEntry']").count
    assert_equal 2, initial_count, "Should have 2 test results initially"

    # Click remove button on first test result
    first_entry = find("[data-review-form-target='testResultEntry']", match: :first)
    within(first_entry) do
      find("button[data-action*='removeTestResult']").click
    end

    sleep 0.4 # Allow for animation and removal

    # Verify test result was removed
    new_count = all("[data-review-form-target='testResultEntry']").count
    assert_equal 1, new_count, "Should have 1 test result after removal"
  end

  test "removing all test results shows empty message" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [
          { biomarker_name: "Glucose", value: "95", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Remove the only test result
    entry = find("[data-review-form-target='testResultEntry']")
    within(entry) do
      find("button[data-action*='removeTestResult']").click
    end

    sleep 0.4

    # Empty message should appear
    assert_text "No test results were extracted"
    assert_selector ".empty-test-results-message"
  end

  test "new test result entry has correct field names with unique index" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [
          { biomarker_name: "Existing Test", value: "100", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Add a new test result
    find("button", text: /Add Test Result/i).click
    sleep 0.3

    # Find the new entry (should have index 1)
    new_entry = find("[data-review-form-target='testResultEntry'][data-test-result-index='1']")

    # Verify field names include the correct index
    within(new_entry) do
      assert_selector "input[name*='test_results[1][biomarker_name]']"
      assert_selector "input[name*='test_results[1][value]']"
      assert_selector "input[name*='test_results[1][unit]']"
    end
  end

  test "new test result focuses first input after addition" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [
          { biomarker_name: "Existing Test", value: "100", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Add a new test result
    find("button", text: /Add Test Result/i).click
    sleep 0.3

    # Check that the new entry's first input is focused
    focused_element = page.evaluate_script("document.activeElement.name")
    assert_match(/test_results\[1\]/, focused_element, "New test result's first input should be focused")
  end

  test "biology report review form integrates biomarker_search autocomplete" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [
          { biomarker_name: "Glucose", value: "95", confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Biomarker name input should have biomarker-search controller
    assert_selector "[data-controller*='biomarker-search']"
    assert_selector "[data-biomarker-search-target='input']"
    assert_selector "[data-biomarker-search-target='results']"
  end

  test "biology report review form includes auto-fill targets for biomarker search" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [
          { biomarker_name: "Glucose", value: "95", unit: "mg/dL", reference_min: 70, reference_max: 100, confidence: 0.9 }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Should have auto-fill targets for unit, ref_min, ref_max
    assert_selector "[data-biomarker-search-target='unitField']"
    assert_selector "[data-biomarker-search-target='refMinField']"
    assert_selector "[data-biomarker-search-target='refMaxField']"
  end

  test "biology report review form highlights out-of-range values" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "150",
            unit: "mg/dL",
            reference_min: 70,
            reference_max: 100,
            out_of_range: true,
            confidence: 0.95
          }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Out-of-range test result entry should have red/danger styling
    entry = find("[data-review-form-target='testResultEntry']")
    assert entry[:class].include?("border-red") || entry[:class].include?("bg-red"),
           "Out-of-range test result should have red/danger visual indicator"

    # Should have out-of-range warning text
    assert_text "outside reference range"
  end

  test "biology report review form shows confidence indicators" do
    sign_in_as_system(@user)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [
          {
            biomarker_name: "Unclear Biomarker",
            value: "123",
            confidence: 0.55
          }
        ]
      }
    )

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Low confidence should show percentage and have warning styling
    assert_text "55%"
    assert_text "Confidence"

    # Entry should have warning border/background
    entry = find("[data-review-form-target='testResultEntry']")
    assert entry[:class].include?("border-yellow") || entry[:class].include?("bg-yellow"),
           "Low confidence test result should have warning visual indicator"
  end

  test "biology report review form shows matched biomarker indicator" do
    sign_in_as_system(@user)

    biomarker = biomarkers(:glucose)

    biology_report = biology_reports(:one)
    biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
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

    visit review_document_scan_path(biology_report, record_type: "biology_report")

    wait_for_stimulus_controller("review-form")

    # Should show matched indicator
    assert_text "Matched in database"
  end
end
