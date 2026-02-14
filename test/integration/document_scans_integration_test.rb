# frozen_string_literal: true

require "test_helper"

# Task 13.1: Integration tests for full scan flow
# Requirements: 1.1, 2.1, 3.1, 4.1, 5.5, 5.6
class DocumentScansIntegrationTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  # --- Task 13.1: Full Prescription Scan Flow Tests ---
  # Requirements: 1.1, 3.1, 5.5

  test "complete prescription scan flow from upload to confirm" do
    # Step 1: Access capture interface
    get new_document_scan_path
    assert_response :success
    assert_select "turbo-frame#document_scan_flow"

    # Step 2: Upload image
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    post upload_document_scans_path, params: { scan: { image: image } }
    assert_response :success

    # Extract blob_id from response
    blob = ActiveStorage::Blob.order(created_at: :desc).first
    assert blob.present?, "Blob should be created after upload"

    # Step 3: Extract with mock success
    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [
        PrescriptionScannerService::ExtractedMedication.new(
          drug_name: "Integration Test Aspirin",
          dosage: "500mg",
          frequency: "daily",
          confidence: 0.95
        )
      ],
      doctor_name: "Dr. Integration",
      prescription_date: "2026-02-10",
      raw_response: {}
    )

    initial_prescription_count = Prescription.count

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: mock_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :success
    assert_match /Integration Test Aspirin/i, response.body
    assert_match /Dr\. Integration/i, response.body

    # Step 4: Confirm and create prescription
    assert_difference "Prescription.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          doctor_name: "Dr. Integration",
          prescribed_date: "2026-02-10",
          medications: [
            {
              drug_name: "Integration Test Aspirin",
              dosage: "500mg",
              frequency: "daily"
            }
          ]
        }
      }
    end

    prescription = Prescription.last
    assert_equal "Dr. Integration", prescription.doctor_name
    assert_equal @user.id, prescription.user_id
    assert_equal "confirmed", prescription.extraction_status
    assert prescription.scanned_document.attached?

    assert_redirected_to prescription_path(prescription)
  end

  # --- Task 13.1: Full Biology Report Scan Flow Tests ---
  # Requirements: 2.1, 4.1, 5.6

  test "complete biology report scan flow from upload to confirm" do
    # Step 1: Access capture interface
    get new_document_scan_path
    assert_response :success

    # Step 2: Upload image
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    post upload_document_scans_path, params: { scan: { image: image } }
    assert_response :success

    blob = ActiveStorage::Blob.order(created_at: :desc).first

    # Step 3: Extract with mock success
    mock_result = BiologyReportScannerService::ExtractionResult.success(
      test_results: [
        BiologyReportScannerService::ExtractedTestResult.new(
          biomarker_name: "Integration Glucose",
          value: "95",
          unit: "mg/dL",
          reference_range: "70-100",
          confidence: 0.92,
          out_of_range: false
        )
      ],
      lab_name: "Integration Lab",
      test_date: "2026-02-10",
      raw_response: {}
    )

    BiologyReportScannerService.stub :new, ->(**args) { OpenStruct.new(call: mock_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id
        }
      }
    end

    assert_response :success
    assert_match /Integration Glucose/i, response.body
    assert_match /Integration Lab/i, response.body

    # Step 4: Confirm and create biology report
    assert_difference "BiologyReport.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id,
          lab_name: "Integration Lab",
          test_date: "2026-02-10",
          test_results: [
            {
              biomarker_name: "Integration Glucose",
              value: "95",
              unit: "mg/dL"
            }
          ]
        }
      }
    end

    report = BiologyReport.last
    assert_equal "Integration Lab", report.lab_name
    assert_equal @user.id, report.user_id
    assert_equal "confirmed", report.extraction_status
    assert report.document.attached?

    assert_redirected_to biology_report_path(report)
  end

  # --- Task 13.1: Background Extraction Flow Tests ---

  test "background extraction flow for prescription with status updates" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "background_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Request background processing
    assert_enqueued_with(job: DocumentExtractionJob) do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          background: "1"
        }
      }
    end

    assert_response :success
    assert_match /processing/i, response.body

    # Verify prescription was created with pending status
    prescription = Prescription.last
    assert_equal "pending", prescription.extraction_status
    assert_equal @user.id, prescription.user_id
  end

  test "background extraction flow for biology_report with status updates" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "background_biology.jpg",
      content_type: "image/jpeg"
    )

    # Request background processing
    assert_enqueued_with(job: DocumentExtractionJob) do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id,
          background: "1"
        }
      }
    end

    assert_response :success
    assert_match /processing/i, response.body

    # Verify biology report was created with pending status
    report = BiologyReport.last
    assert_equal "pending", report.extraction_status
    assert_equal @user.id, report.user_id
  end

  # --- Task 13.1: Cancellation Tests at Each Step ---

  test "cancellation at upload step returns to capture interface" do
    # Upload an image
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    post upload_document_scans_path, params: { scan: { image: image } }
    assert_response :success

    # Cancel by navigating back
    get new_document_scan_path
    assert_response :success
    assert_select "turbo-frame#document_scan_flow"

    # No prescription should have been created
    # (Note: blobs may exist but no prescription record)
  end

  test "cancellation at type selection step preserves nothing" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    # Navigate to type selection
    get select_type_document_scans_path, params: { blob_id: blob.id }
    assert_response :success

    # Cancel by navigating to new scan
    get new_document_scan_path
    assert_response :success

    # No records created
    assert_nil Prescription.find_by(scanned_document_blob_id: blob.id)
    assert_nil BiologyReport.find_by(document_blob_id: blob.id)
  end

  test "cancellation at review step discards extracted data" do
    # Create a prescription with extracted status
    prescription = Prescription.create!(
      user: @user,
      doctor_name: "Dr. Cancel",
      prescribed_date: Date.today,
      extraction_status: :extracted,
      extracted_data: { doctor_name: "Dr. Cancel", medications: [] }
    )

    # Cancel the extraction (delete the pending record)
    delete cancel_document_scan_path(prescription, record_type: "prescription")

    assert_redirected_to new_document_scan_path
    assert_nil Prescription.find_by(id: prescription.id)
  end

  test "cancellation of pending background extraction deletes record" do
    # Create a pending prescription (simulating background extraction)
    prescription = Prescription.create!(
      user: @user,
      doctor_name: "Dr. Pending",
      prescribed_date: Date.today,
      extraction_status: :pending
    )

    # Cancel should delete the pending record
    assert_difference "Prescription.count", -1 do
      delete cancel_document_scan_path(prescription, record_type: "prescription")
    end

    assert_redirected_to new_document_scan_path
  end

  # --- Task 13.1: Mock Claude API Response Tests ---

  test "extraction handles multiple medications from single prescription image" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "multi_med_prescription.jpg",
      content_type: "image/jpeg"
    )

    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [
        PrescriptionScannerService::ExtractedMedication.new(
          drug_name: "Medication One",
          dosage: "100mg",
          frequency: "once daily",
          confidence: 0.95
        ),
        PrescriptionScannerService::ExtractedMedication.new(
          drug_name: "Medication Two",
          dosage: "50mg",
          frequency: "twice daily",
          confidence: 0.88
        ),
        PrescriptionScannerService::ExtractedMedication.new(
          drug_name: "Medication Three",
          dosage: "25mg",
          frequency: "as needed",
          confidence: 0.72  # Low confidence
        )
      ],
      doctor_name: "Dr. Multi",
      prescription_date: "2026-02-10",
      raw_response: {}
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: mock_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :success
    assert_match /Medication One/i, response.body
    assert_match /Medication Two/i, response.body
    assert_match /Medication Three/i, response.body
  end

  test "extraction handles multiple test results from single biology report image" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "multi_test_report.jpg",
      content_type: "image/jpeg"
    )

    mock_result = BiologyReportScannerService::ExtractionResult.success(
      test_results: [
        BiologyReportScannerService::ExtractedTestResult.new(
          biomarker_name: "Glucose",
          value: "95",
          unit: "mg/dL",
          reference_range: "70-100",
          confidence: 0.95,
          out_of_range: false
        ),
        BiologyReportScannerService::ExtractedTestResult.new(
          biomarker_name: "Cholesterol",
          value: "220",
          unit: "mg/dL",
          reference_range: "0-200",
          confidence: 0.92,
          out_of_range: true  # Out of range
        ),
        BiologyReportScannerService::ExtractedTestResult.new(
          biomarker_name: "Hemoglobin",
          value: "14.5",
          unit: "g/dL",
          reference_range: "12-17",
          confidence: 0.88,
          out_of_range: false
        )
      ],
      lab_name: "Multi Test Lab",
      test_date: "2026-02-10",
      raw_response: {}
    )

    BiologyReportScannerService.stub :new, ->(**args) { OpenStruct.new(call: mock_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id
        }
      }
    end

    assert_response :success
    assert_match /Glucose/i, response.body
    assert_match /Cholesterol/i, response.body
    assert_match /Hemoglobin/i, response.body
  end

  private

  def sign_in_as(user)
    post sessions_path, params: { session: { email: user.email, password: "password" } }
  end
end
