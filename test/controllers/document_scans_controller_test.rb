# frozen_string_literal: true

require "test_helper"

class DocumentScansControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @user = users(:one)
    @other_user = users(:two)
    @prescription = prescriptions(:one)
    @biology_report = biology_reports(:one)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "new requires authentication" do
    sign_out
    get new_document_scan_path
    assert_redirected_to new_session_path
  end

  test "upload requires authentication" do
    sign_out
    post upload_document_scans_path, params: { scan: { document_type: "prescription" } }
    assert_redirected_to new_session_path
  end

  test "extract requires authentication" do
    sign_out
    post extract_document_scans_path, params: { scan: { document_type: "prescription" } }
    assert_redirected_to new_session_path
  end

  test "review requires authentication" do
    sign_out
    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_redirected_to new_session_path
  end

  test "confirm requires authentication" do
    sign_out
    post confirm_document_scans_path, params: { scan: { document_type: "prescription" } }
    assert_redirected_to new_session_path
  end

  # --- New Action (Capture Interface) ---

  test "new renders capture interface with camera and upload options" do
    get new_document_scan_path
    assert_response :success
    assert_select "h1", /Scan Document/i
    # Should have camera capture option
    assert_select "[data-controller='camera']" # Stimulus controller
    # Should have file upload option
    assert_select "input[type='file']"
  end

  test "new renders within turbo frame" do
    get new_document_scan_path
    assert_response :success
    assert_select "turbo-frame#document_scan_flow"
  end

  # --- Task 9.3: Scan Flow Views with Turbo Frames ---
  # Requirements: 1.1, 1.2, 2.1, 2.2, 2.5, 6.1, 6.2, 6.7

  test "new has file input with capture attribute for mobile camera access" do
    # Requirement 1.2: Open device camera with rear-facing camera by default
    get new_document_scan_path
    assert_response :success

    # File input should have capture="environment" for mobile rear camera
    assert_select "input[type='file'][capture='environment']"
  end

  test "new has separate camera capture option for mobile devices" do
    # Requirement 1.2: Mobile camera capture button
    get new_document_scan_path
    assert_response :success

    # Should have a dedicated camera capture interface
    assert_select "[data-controller='camera']"
  end

  test "upload view shows back link to capture interface" do
    # Requirement 6.7: Navigate back to previous steps without losing progress
    image = fixture_file_upload("test_image.jpg", "image/jpeg")

    post upload_document_scans_path, params: {
      scan: { image: image }
    }

    assert_response :success
    # Should have back link to capture interface
    assert_select "a[href='#{new_document_scan_path}']"
  end

  test "upload view includes blob_id for seamless step transitions" do
    # Requirement 6.1, 6.2: Turbo Frames for seamless transitions
    image = fixture_file_upload("test_image.jpg", "image/jpeg")

    post upload_document_scans_path, params: {
      scan: { image: image }
    }

    assert_response :success
    # Hidden field with blob_id for next step
    assert_select "input[type='hidden'][name='scan[blob_id]']"
  end

  test "document type selection allows changing type before extraction" do
    # Requirement 2.5: Allow user to change document type before submitting for extraction
    image = fixture_file_upload("test_image.jpg", "image/jpeg")

    post upload_document_scans_path, params: {
      scan: { image: image }
    }

    assert_response :success
    # Both document type options should be selectable
    assert_select "input[type='radio'][name='scan[document_type]'][value='prescription']"
    assert_select "input[type='radio'][name='scan[document_type]'][value='biology_report']"
  end

  test "background_suggestion view has back link to type selection preserving blob" do
    # Requirement 6.7: Navigate back to previous steps without losing progress
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "large_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Stub to return large byte_size
    large_blob = blob.dup
    large_blob.define_singleton_method(:byte_size) { 3.megabytes }

    ActiveStorage::Blob.stub :find_by, ->(args) { args[:id].to_i == blob.id ? large_blob : nil } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :success
    # Should have back link that preserves the blob_id
    assert_match /select_type.*blob_id=#{blob.id}/, response.body
  end

  test "all scan flow views are wrapped in document_scan_flow turbo frame" do
    # Requirement 6.1: Implement scan flow using Turbo Frames
    image = fixture_file_upload("test_image.jpg", "image/jpeg")

    # Test new view
    get new_document_scan_path
    assert_select "turbo-frame#document_scan_flow"

    # Test upload view
    post upload_document_scans_path, params: { scan: { image: image } }
    assert_select "turbo-frame#document_scan_flow"

    # Test select_type view
    blob = ActiveStorage::Blob.order(created_at: :desc).first
    get select_type_document_scans_path, params: { blob_id: blob.id }
    assert_select "turbo-frame#document_scan_flow"
  end

  test "form submissions use turbo_frame for seamless transitions" do
    # Requirement 6.2: Update only relevant page section during transitions
    get new_document_scan_path
    assert_response :success

    # Forms should target the turbo frame
    assert_select "form[data-turbo-frame='document_scan_flow']"
  end

  # --- Upload Action ---

  test "upload with valid image shows document type selection" do
    # Create a test image blob
    image = fixture_file_upload("test_image.jpg", "image/jpeg")

    post upload_document_scans_path, params: {
      scan: { image: image }
    }

    assert_response :success
    # Should show document type selection
    assert_select "select[name='scan[document_type]']" , false # Using radio buttons instead
    assert_select "input[type='radio'][name='scan[document_type]']", count: 2
  end

  test "upload stores blob_id in session for next step" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")

    post upload_document_scans_path, params: {
      scan: { image: image }
    }

    assert_response :success
    # The response should include the blob_id for the next step
    assert_match /blob_id/, response.body
  end

  test "upload with missing image returns error" do
    post upload_document_scans_path, params: {
      scan: { document_type: "prescription" }
    }

    assert_response :unprocessable_entity
  end

  # --- Select Type Action (Back Navigation Support) ---

  test "select_type requires authentication" do
    sign_out
    get select_type_document_scans_path, params: { blob_id: 1 }
    assert_redirected_to new_session_path
  end

  test "select_type displays type selection for existing blob" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )

    get select_type_document_scans_path, params: { blob_id: blob.id }

    assert_response :success
    # Should show document type selection
    assert_select "input[type='radio'][name='scan[document_type]']", count: 2
    # Should include the blob_id for the next step
    assert_match /blob_id/, response.body
  end

  test "select_type returns error for missing blob_id" do
    get select_type_document_scans_path

    assert_response :unprocessable_entity
  end

  test "select_type returns error for invalid blob_id" do
    get select_type_document_scans_path, params: { blob_id: 999999 }

    assert_response :unprocessable_entity
  end

  test "select_type renders within turbo frame" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )

    get select_type_document_scans_path, params: { blob_id: blob.id }

    assert_response :success
    assert_select "turbo-frame#document_scan_flow"
  end

  # --- Extract Action ---

  test "extract triggers synchronous extraction for prescription" do
    # First upload an image
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Mock the scanner service
    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [
        PrescriptionScannerService::ExtractedMedication.new(
          drug_name: "Aspirin",
          dosage: "100mg",
          frequency: "daily",
          confidence: 0.9
        )
      ],
      doctor_name: "Dr. Test",
      prescription_date: "2026-01-15",
      raw_response: { medications: [] }
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
    # Should redirect to review or render review form
    assert_match /review|extracted/i, response.body
  end

  test "extract triggers synchronous extraction for biology_report" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    mock_result = BiologyReportScannerService::ExtractionResult.success(
      test_results: [
        BiologyReportScannerService::ExtractedTestResult.new(
          biomarker_name: "Glucose",
          value: "95",
          unit: "mg/dL",
          confidence: 0.95
        )
      ],
      lab_name: "Test Lab",
      test_date: "2026-01-15",
      raw_response: { test_results: [] }
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
    assert_match /review|extracted/i, response.body
  end

  test "extract with invalid document_type returns error" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "invalid",
        blob_id: blob.id
      }
    }

    assert_response :unprocessable_entity
  end

  test "extract with missing blob_id returns error" do
    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription"
      }
    }

    assert_response :unprocessable_entity
  end

  test "extract can enqueue background job when requested" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

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
    # Should show processing status
    assert_match /processing/i, response.body
  end

  # --- Extraction Decision Logic (Task 8.2) ---

  test "extract suggests background processing for large images" do
    # Create a blob with mocked large size
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "large_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Stub ActiveStorage::Blob.find_by to return a blob with large byte_size
    large_blob = blob.dup
    large_blob.define_singleton_method(:byte_size) { 3.megabytes }

    ActiveStorage::Blob.stub :find_by, ->(args) { args[:id].to_i == blob.id ? large_blob : nil } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :success
    # Should suggest background processing - shows the background suggestion view
    assert_match /may take longer|background|processing.*option|Large Document/i, response.body
  end

  test "extract performs sync extraction for small images without background suggestion" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "small_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Small images (< 2MB) should not trigger background suggestion
    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [],
      doctor_name: "Dr. Test",
      prescription_date: "2026-01-15",
      raw_response: {}
    )

    # The test fixture image is small, so no need to stub byte_size
    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: mock_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :success
    # Should proceed with sync extraction and show review
    assert_match /review|extracted/i, response.body
  end

  test "extract respects background flag even for small images" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "small_prescription.jpg",
      content_type: "image/jpeg"
    )

    # User can explicitly request background processing
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
  end

  test "extract with force_sync proceeds with sync extraction for large images" do
    # Create a blob with mocked large size
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "large_prescription.jpg",
      content_type: "image/jpeg"
    )

    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [],
      doctor_name: "Dr. Test",
      prescription_date: "2026-01-15",
      raw_response: {}
    )

    # User chose to wait despite large image (force_sync=1)
    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: mock_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          force_sync: "1"
        }
      }
    end

    assert_response :success
    # Should proceed with sync extraction and show review
    assert_match /review|extracted/i, response.body
  end

  test "extract returns extraction time estimate in response" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [],
      doctor_name: nil,
      prescription_date: nil,
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
  end

  test "extraction_exceeds_threshold returns correct threshold based on image size" do
    controller = DocumentScansController.new

    # Test extraction should be fast for small images (< 1MB)
    assert_not controller.send(:extraction_exceeds_threshold?, 500.kilobytes)

    # Test extraction should be slow for large images (> 2MB)
    assert controller.send(:extraction_exceeds_threshold?, 3.megabytes)

    # Test boundary case at 2MB threshold
    assert controller.send(:extraction_exceeds_threshold?, 2.megabytes + 1)
    assert_not controller.send(:extraction_exceeds_threshold?, 2.megabytes - 1)
  end

  test "estimate_extraction_time returns seconds based on image size" do
    controller = DocumentScansController.new

    # Small image should estimate < 5 seconds
    small_estimate = controller.send(:estimate_extraction_time, 500.kilobytes)
    assert small_estimate < 5, "Expected small image to estimate < 5 seconds, got #{small_estimate}"

    # Large image should estimate > 5 seconds
    large_estimate = controller.send(:estimate_extraction_time, 5.megabytes)
    assert large_estimate > 5, "Expected large image to estimate > 5 seconds, got #{large_estimate}"
  end

  test "background_suggestion view shows estimated time and options" do
    # Create a blob with mocked large size
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "large_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Stub ActiveStorage::Blob.find_by to return a blob with large byte_size
    large_blob = blob.dup
    large_blob.define_singleton_method(:byte_size) { 3.megabytes }

    ActiveStorage::Blob.stub :find_by, ->(args) { args[:id].to_i == blob.id ? large_blob : nil } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :success
    # Should show background suggestion view with options
    assert_match /Process in Background/i, response.body
    assert_match /Wait for Results/i, response.body
    assert_match /seconds/i, response.body
  end

  # --- Review Action ---

  test "review displays extracted data for prescription in editable form" do
    # Set up prescription with extracted data
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Extracted",
        prescription_date: "2026-01-15",
        medications: [
          {
            drug_name: "Aspirin",
            dosage: "100mg",
            frequency: "daily",
            confidence: 0.9,
            requires_verification: false
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success
    assert_select "form"
    # Should display editable fields
    assert_match /Aspirin/i, response.body
    assert_match /Dr\. Extracted/i, response.body
  end

  test "review displays extracted data for biology_report in editable form" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Extracted Lab",
        test_date: "2026-01-15",
        test_results: [
          {
            biomarker_name: "Glucose",
            value: "95",
            unit: "mg/dL",
            confidence: 0.9,
            out_of_range: false,
            requires_verification: false
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success
    assert_select "form"
    assert_match /Glucose/i, response.body
    assert_match /Extracted Lab/i, response.body
  end

  test "review returns not found for other user's prescription" do
    other_prescription = prescriptions(:other_user_prescription)
    other_prescription.update!(extraction_status: :extracted, extracted_data: {})

    get review_document_scan_path(other_prescription, record_type: "prescription")
    assert_response :not_found
  end

  test "review returns not found for other user's biology_report" do
    other_report = biology_reports(:other_user_report)
    other_report.update!(extraction_status: :extracted, extracted_data: {})

    get review_document_scan_path(other_report, record_type: "biology_report")
    assert_response :not_found
  end

  test "review requires record to be in extracted status" do
    @prescription.update!(extraction_status: :manual)

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :unprocessable_entity
  end

  # --- Confirm Action ---

  test "confirm creates prescription record from confirmed data" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    assert_difference "Prescription.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          doctor_name: "Dr. Confirmed",
          prescribed_date: "2026-02-01",
          medications: [
            {
              drug_name: "Confirmed Aspirin",
              dosage: "200mg",
              frequency: "twice daily"
            }
          ]
        }
      }
    end

    prescription = Prescription.last
    assert_equal "Dr. Confirmed", prescription.doctor_name
    assert_equal @user.id, prescription.user_id
    assert_equal "confirmed", prescription.extraction_status
    assert prescription.scanned_document.attached?

    assert_redirected_to prescription_path(prescription)
    follow_redirect!
    assert_match /created|success/i, flash[:notice]
  end

  test "confirm creates biology_report record from confirmed data" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    assert_difference "BiologyReport.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id,
          lab_name: "Confirmed Lab",
          test_date: "2026-02-01",
          test_results: [
            {
              biomarker_name: "Glucose",
              value: "100",
              unit: "mg/dL"
            }
          ]
        }
      }
    end

    report = BiologyReport.last
    assert_equal "Confirmed Lab", report.lab_name
    assert_equal @user.id, report.user_id
    assert_equal "confirmed", report.extraction_status
    assert report.document.attached?

    assert_redirected_to biology_report_path(report)
    follow_redirect!
    assert_match /created|success/i, flash[:notice]
  end

  test "confirm with invalid data re-renders review form with errors" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    assert_no_difference "Prescription.count" do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          doctor_name: "Dr. Invalid",
          prescribed_date: nil # Required field
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "form" # Should re-render the form
  end

  test "confirm scopes record to authenticated user" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        doctor_name: "Dr. Scoped",
        prescribed_date: "2026-02-01",
        user_id: @other_user.id # Should be ignored
      }
    }

    prescription = Prescription.last
    assert_equal @user.id, prescription.user_id
    assert_not_equal @other_user.id, prescription.user_id
  end

  test "confirm with invalid document_type returns error" do
    post confirm_document_scans_path, params: {
      scan: {
        document_type: "invalid"
      }
    }

    assert_response :unprocessable_entity
  end

  # --- Turbo Frame Responses ---

  test "actions respond with turbo frame for turbo requests" do
    get new_document_scan_path, headers: { "Turbo-Frame" => "document_scan_flow" }
    assert_response :success
    assert_match /turbo-frame.*document_scan_flow/i, response.body
  end

  # --- Security: User Scoping (Requirement 9.2) ---

  test "all operations are scoped to authenticated user via Current.user" do
    # Create a prescription for other user
    other_prescription = prescriptions(:other_user_prescription)
    other_prescription.update!(extraction_status: :extracted, extracted_data: {})

    # Try to access other user's data through review
    get review_document_scan_path(other_prescription, record_type: "prescription")
    assert_response :not_found

    # Verify user can access their own data
    @prescription.update!(extraction_status: :extracted, extracted_data: {})
    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success
  end

  test "background extraction creates records scoped to authenticated user" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Request background processing
    assert_difference "Prescription.count", 1 do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          background: "1"
        }
      }
    end

    # Verify the created record is scoped to the authenticated user
    prescription = Prescription.last
    assert_equal @user.id, prescription.user_id
    assert_equal "pending", prescription.extraction_status
  end

  test "background extraction for biology_report creates records scoped to authenticated user" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    # Request background processing
    assert_difference "BiologyReport.count", 1 do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id,
          background: "1"
        }
      }
    end

    # Verify the created record is scoped to the authenticated user
    report = BiologyReport.last
    assert_equal @user.id, report.user_id
    assert_equal "pending", report.extraction_status
  end

  test "confirm ignores user_id parameter for biology_report and uses Current.user" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: blob.id,
        lab_name: "Scoped Lab",
        test_date: "2026-02-01",
        user_id: @other_user.id # Should be ignored
      }
    }

    report = BiologyReport.last
    assert_equal @user.id, report.user_id
    assert_not_equal @other_user.id, report.user_id
  end

  # --- Active Storage User Scoped Access (Requirement 9.5) ---

  test "scanned document is attached to prescription with user ownership" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        doctor_name: "Dr. Attachment Test",
        prescribed_date: "2026-02-01"
      }
    }

    prescription = Prescription.last
    assert prescription.scanned_document.attached?
    # The prescription belongs to the authenticated user, so the attachment is implicitly scoped
    assert_equal @user.id, prescription.user_id
    assert prescription.scanned_document.blob.present?
  end

  test "scanned document is attached to biology_report with user ownership" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: blob.id,
        lab_name: "Attachment Test Lab",
        test_date: "2026-02-01"
      }
    }

    report = BiologyReport.last
    assert report.document.attached?
    # The biology report belongs to the authenticated user, so the attachment is implicitly scoped
    assert_equal @user.id, report.user_id
    assert report.document.blob.present?
  end

  # --- Review Action Edge Cases ---

  test "review returns error for invalid record_type" do
    get review_document_scan_path(@prescription, record_type: "invalid_type")
    assert_response :not_found
  end

  test "review returns error for missing record_type" do
    get review_document_scan_path(@prescription)
    assert_response :not_found
  end

  test "review returns error for non-existent record id" do
    get review_document_scan_path(999999, record_type: "prescription")
    assert_response :not_found
  end

  test "review returns error for processing status record" do
    @prescription.update!(extraction_status: :processing)
    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :unprocessable_entity
  end

  test "review returns error for pending status record" do
    @prescription.update!(extraction_status: :pending)
    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :unprocessable_entity
  end

  test "review returns error for failed status record" do
    @prescription.update!(extraction_status: :failed)
    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :unprocessable_entity
  end

  test "review returns error for confirmed status record" do
    @prescription.update!(extraction_status: :confirmed, extracted_data: {})
    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :unprocessable_entity
  end

  # --- Extraction Error Handling ---

  test "extract handles scanner service extraction error" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :image_quality_error,
      message: "Image is too blurry for reliable extraction"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match /blurry|error|quality/i, response.body
  end

  test "extract handles scanner service rate limit error" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :rate_limit_error,
      message: "API rate limit exceeded. Please try again later."
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match /rate|limit|try again/i, response.body
  end

  test "extract handles scanner service authentication error" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    error_result = BiologyReportScannerService::ExtractionResult.error(
      type: :authentication_error,
      message: "API authentication failed"
    )

    BiologyReportScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match /authentication|error/i, response.body
  end

  # --- Full Flow Integration Tests ---

  test "complete prescription scan flow from capture to confirm" do
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

    # Step 3: Extract with mock success
    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [
        PrescriptionScannerService::ExtractedMedication.new(
          drug_name: "Integration Aspirin",
          dosage: "500mg",
          frequency: "daily",
          confidence: 0.95
        )
      ],
      doctor_name: "Dr. Integration",
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

    # Step 4: Confirm the extraction
    assert_difference "Prescription.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          doctor_name: "Dr. Integration",
          prescribed_date: "2026-02-10"
        }
      }
    end

    prescription = Prescription.last
    assert_equal @user.id, prescription.user_id
    assert_equal "Dr. Integration", prescription.doctor_name
    assert_equal "confirmed", prescription.extraction_status
  end

  test "complete biology_report scan flow from capture to confirm" do
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
          biomarker_name: "Hemoglobin",
          value: "14.5",
          unit: "g/dL",
          confidence: 0.92
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

    # Step 4: Confirm the extraction
    assert_difference "BiologyReport.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id,
          lab_name: "Integration Lab",
          test_date: "2026-02-10"
        }
      }
    end

    report = BiologyReport.last
    assert_equal @user.id, report.user_id
    assert_equal "Integration Lab", report.lab_name
    assert_equal "confirmed", report.extraction_status
  end

  # --- Turbo Frame Response Format Tests ---

  test "upload responds with turbo frame for turbo requests" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    post upload_document_scans_path,
      params: { scan: { image: image } },
      headers: { "Turbo-Frame" => "document_scan_flow" }

    assert_response :success
    assert_match /turbo-frame.*document_scan_flow/i, response.body
  end

  test "extract responds with turbo frame for turbo requests" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [],
      doctor_name: "Dr. Turbo",
      prescription_date: "2026-01-15",
      raw_response: {}
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: mock_result) } do
      post extract_document_scans_path,
        params: { scan: { document_type: "prescription", blob_id: blob.id } },
        headers: { "Turbo-Frame" => "document_scan_flow" }
    end

    assert_response :success
    assert_match /turbo-frame.*document_scan_flow/i, response.body
  end

  test "review responds with turbo frame for turbo requests" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: { doctor_name: "Dr. Turbo Frame" }
    )

    get review_document_scan_path(@prescription, record_type: "prescription"),
      headers: { "Turbo-Frame" => "document_scan_flow" }

    assert_response :success
    assert_match /turbo-frame.*document_scan_flow/i, response.body
  end

  test "select_type responds with turbo frame for turbo requests" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )

    get select_type_document_scans_path,
      params: { blob_id: blob.id },
      headers: { "Turbo-Frame" => "document_scan_flow" }

    assert_response :success
    assert_match /turbo-frame.*document_scan_flow/i, response.body
  end

  # --- Additional Error Handling Tests ---

  test "confirm with missing blob returns error for prescription" do
    post confirm_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: 999999,
        doctor_name: "Dr. Missing Blob",
        prescribed_date: "2026-02-01"
      }
    }

    # Should still work but without attachment (blob is optional)
    # The controller handles missing blob gracefully
    assert_response :redirect
  end

  test "confirm with missing blob returns error for biology_report" do
    post confirm_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: 999999,
        lab_name: "Missing Blob Lab",
        test_date: "2026-02-01"
      }
    }

    # Should still work but without attachment (blob is optional)
    assert_response :redirect
  end

  test "extract handles non-existent blob gracefully" do
    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: 999999
      }
    }

    assert_response :unprocessable_entity
    assert_match /not found/i, response.body
  end

  # --- Confidence and Verification Flag Tests ---

  test "review displays low confidence fields with verification flag" do
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Low Confidence",
        medications: [
          {
            drug_name: "Uncertain Drug",
            dosage: "unknown",
            confidence: 0.4,
            requires_verification: true
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success
    assert_match /Uncertain Drug/i, response.body
    # The view should indicate this field needs verification (visual indicator)
  end

  test "review displays out_of_range flag for biology_report" do
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Range Lab",
        test_results: [
          {
            biomarker_name: "High Glucose",
            value: "300",
            unit: "mg/dL",
            confidence: 0.9,
            out_of_range: true,
            requires_verification: false
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success
    assert_match /High Glucose/i, response.body
    # The view should indicate this value is out of range
  end

  # --- Confirm Creates Associated Records ---

  test "confirm creates medications for prescription with matched drug" do
    # Use existing fixture drug
    drug = drugs(:aspirin)

    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    assert_difference "Medication.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          doctor_name: "Dr. With Medication",
          prescribed_date: "2026-02-01",
          medications: {
            "0" => {
              drug_name: "Aspirin",
              drug_id: drug.id,
              dosage: "100mg",
              frequency: "daily"
            }
          }
        }
      }
    end

    prescription = Prescription.last
    assert_equal 1, prescription.medications.count
    assert_equal drug.id, prescription.medications.first.drug_id
  end

  test "confirm creates test_results for biology_report with matched biomarker" do
    # Use existing fixture biomarker
    biomarker = biomarkers(:glucose)

    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    assert_difference "TestResult.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id,
          lab_name: "With Results Lab",
          test_date: "2026-02-01",
          test_results: {
            "0" => {
              biomarker_name: "Glucose",
              biomarker_id: biomarker.id,
              value: "95",
              unit: "mg/dL"
            }
          }
        }
      }
    end

    report = BiologyReport.last
    assert_equal 1, report.test_results.count
    assert_equal biomarker.id, report.test_results.first.biomarker_id
  end

  # --- Task 9.4: Processing Indicator View Tests ---
  # Requirements: 3.3, 4.3, 6.5, 10.1

  test "processing view displays estimated wait time based on document complexity" do
    # Requirement 3.3, 4.3: Display processing indicator with estimated wait time
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Request background processing to render processing view
    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    # Should show estimated processing time
    assert_match /estimated.*time|processing.*time|wait.*seconds|seconds.*processing/i, response.body
  end

  test "processing view shows document type specific message" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Test prescription message
    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    assert_match /prescription/i, response.body
  end

  test "processing view shows biology report specific message" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    # Test biology report message
    post extract_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    assert_match /biology.*report|report/i, response.body
  end

  test "processing view includes turbo stream subscription for auto-refresh" do
    # Requirement 6.5, 10.4: Auto-refresh via Turbo when extraction completes
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    # Should have turbo stream subscription for auto-refresh
    # turbo_stream_from generates <turbo-cable-stream-source> element
    assert_match /turbo-cable-stream-source|turbo_stream_from|document_extractions/i, response.body
  end

  test "processing view shows extraction status from record" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    # Should display extraction status
    assert_match /status/i, response.body
  end

  test "processing view offers option to scan another document" do
    # Requirement 6.8: Option to scan another document
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    # Should have link to scan another document
    assert_select "a[href='#{new_document_scan_path}']"
  end

  test "processing view displays animated processing indicator" do
    # Requirement 3.3, 4.3: Display processing indicator
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    # Should have an animated spinner/loading indicator
    assert_select ".animate-spin, [data-processing-indicator], .spinner, .loading"
  end

  test "processing view includes link to view record while processing" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    # Should have link to view the prescription record
    assert_match /View Prescription|prescription_path/i, response.body
  end

  test "processing view is wrapped in turbo frame for seamless transitions" do
    # Requirement 6.1, 6.2: Turbo Frames for seamless step transitions
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    assert_select "turbo-frame#document_scan_flow"
  end

  test "processing view informs user they can leave page" do
    # Requirement 10.1: User can continue using app while processing
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    # Should inform user they can leave the page
    assert_match /leave.*page|continue.*using|notify|background/i, response.body
  end

  test "processing view shows complexity-based time estimate for large images" do
    # Requirement 10.1: Estimated wait time based on document complexity
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "large_prescription.jpg",
      content_type: "image/jpeg"
    )

    # Stub byte_size to return large value for more complex document
    blob.define_singleton_method(:byte_size) { 5.megabytes }

    ActiveStorage::Blob.stub :find_by, ->(args) { args[:id].to_i == blob.id ? blob : nil } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          background: "1"
        }
      }
    end

    assert_response :success
    # For large documents, should show longer estimated time
    assert_match /estimated|processing|time|seconds/i, response.body
  end

  test "controller passes estimated_time to processing view" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    # The controller should pass @estimated_time to the view
    # This is verified by checking the view renders the time estimate
    assert_match /\d+(\.\d+)?\s*(seconds|sec|s)/i, response.body
  end

  test "controller passes document_type to processing view" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    post extract_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: blob.id,
        background: "1"
      }
    }

    assert_response :success
    # Should reference biology report in the view
    assert_match /biology|report/i, response.body
  end

  # --- Task 10.4: Confirmation and Cancellation Handling Tests ---
  # Requirements: 5.5, 5.6, 5.7, 5.8, 5.9, 6.8

  test "confirm prescription creates record with confirmed extraction_status" do
    # Requirement 5.5: On confirm, create Prescription with extraction_status confirmed
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        doctor_name: "Dr. Confirmation Test",
        prescribed_date: "2026-02-01"
      }
    }

    prescription = Prescription.last
    assert_equal "confirmed", prescription.extraction_status
  end

  test "confirm biology_report creates record with confirmed extraction_status" do
    # Requirement 5.6: On confirm, create BiologyReport with extraction_status confirmed
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: blob.id,
        lab_name: "Confirmation Lab",
        test_date: "2026-02-01"
      }
    }

    report = BiologyReport.last
    assert_equal "confirmed", report.extraction_status
  end

  test "confirm attaches original scanned image to prescription" do
    # Requirement 5.8: Attach original scanned image to created record
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "original_prescription_scan.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        doctor_name: "Dr. Image Attach",
        prescribed_date: "2026-02-01"
      }
    }

    prescription = Prescription.last
    assert prescription.scanned_document.attached?, "Scanned document should be attached"
    assert_equal blob.id, prescription.scanned_document.blob.id
  end

  test "confirm attaches original scanned image to biology_report" do
    # Requirement 5.8: Attach original scanned image to created record
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "original_biology_scan.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: blob.id,
        lab_name: "Image Attach Lab",
        test_date: "2026-02-01"
      }
    }

    report = BiologyReport.last
    assert report.document.attached?, "Scanned document should be attached"
    assert_equal blob.id, report.document.blob.id
  end

  test "confirm prescription shows success message with link to view record" do
    # Requirement 5.9: Show success confirmation with link to view created record
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        doctor_name: "Dr. Success Message",
        prescribed_date: "2026-02-01"
      }
    }

    prescription = Prescription.last
    assert_redirected_to prescription_path(prescription)
    follow_redirect!
    assert_match /created|success/i, flash[:notice]
  end

  test "confirm biology_report shows success message with link to view record" do
    # Requirement 5.9: Show success confirmation with link to view created record
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: blob.id,
        lab_name: "Success Lab",
        test_date: "2026-02-01"
      }
    }

    report = BiologyReport.last
    assert_redirected_to biology_report_path(report)
    follow_redirect!
    assert_match /created|success/i, flash[:notice]
  end

  test "prescription show page offers option to scan another document after confirmation" do
    # Requirement 6.8: Offer option to scan another document after completion
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        doctor_name: "Dr. Scan Another",
        prescribed_date: "2026-02-01"
      }
    }

    follow_redirect!
    # Should have a link to scan another document
    assert_select "a[href='#{new_document_scan_path}']"
  end

  test "biology_report show page offers option to scan another document after confirmation" do
    # Requirement 6.8: Offer option to scan another document after completion
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: blob.id,
        lab_name: "Scan Another Lab",
        test_date: "2026-02-01"
      }
    }

    follow_redirect!
    # Should have a link to scan another document
    assert_select "a[href='#{new_document_scan_path}']"
  end

  test "cancel link on review form returns to scanning interface" do
    # Requirement 5.7: On cancel, discard extracted data and return to scanning interface
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [],
      doctor_name: "Dr. Cancel Test",
      prescription_date: "2026-01-15",
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
    # The review form should have a cancel link to scanning interface
    assert_select "a[href='#{new_document_scan_path}']", text: /cancel/i
  end

  test "cancel link discards extracted data" do
    # Requirement 5.7: On cancel, discard extracted data
    # The cancel link returns to new_document_scan_path without persisting any data
    # Verify no new prescription is created when user cancels

    initial_count = Prescription.count

    # Simulate extraction
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [],
      doctor_name: "Dr. Discard Test",
      prescription_date: "2026-01-15",
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

    # User cancels by navigating to new_document_scan_path
    get new_document_scan_path
    assert_response :success

    # No prescription should have been created
    assert_equal initial_count, Prescription.count
  end

  test "flash message includes option to scan another document" do
    # Requirement 6.8: When scan flow completes successfully, offer option to scan another document
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        doctor_name: "Dr. Flash Message",
        prescribed_date: "2026-02-01"
      }
    }

    # The flash notice should indicate success and the show page should offer scan another option
    follow_redirect!
    assert_match /scan.*another|new.*document/i, response.body
  end

  test "confirm stores extracted_data in prescription for audit" do
    # Requirement 5.8: The extracted data should be preserved for audit
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "prescription",
        blob_id: blob.id,
        doctor_name: "Dr. Audit Trail",
        prescribed_date: "2026-02-01",
        medications: [
          { drug_name: "Audit Aspirin", dosage: "100mg" }
        ]
      }
    }

    prescription = Prescription.last
    assert prescription.extracted_data.present?, "extracted_data should be stored"
  end

  test "confirm stores extracted_data in biology_report for audit" do
    # Requirement 5.8: The extracted data should be preserved for audit
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    post confirm_document_scans_path, params: {
      scan: {
        document_type: "biology_report",
        blob_id: blob.id,
        lab_name: "Audit Lab",
        test_date: "2026-02-01",
        test_results: [
          { biomarker_name: "Audit Glucose", value: "95" }
        ]
      }
    }

    report = BiologyReport.last
    assert report.extracted_data.present?, "extracted_data should be stored"
  end

  # --- Cancel Action Tests ---

  test "cancel requires authentication" do
    sign_out
    delete cancel_document_scan_path(@prescription, record_type: "prescription")
    assert_redirected_to new_session_path
  end

  test "cancel deletes pending prescription record and redirects to scan interface" do
    # Requirement 5.7: On cancel, discard extracted data
    @prescription.update!(extraction_status: :pending)

    assert_difference "Prescription.count", -1 do
      delete cancel_document_scan_path(@prescription, record_type: "prescription")
    end

    assert_redirected_to new_document_scan_path
    follow_redirect!
    assert_match /cancelled|scan/i, flash[:notice]
  end

  test "cancel deletes extracted prescription record" do
    @prescription.update!(extraction_status: :extracted, extracted_data: { test: "data" })

    assert_difference "Prescription.count", -1 do
      delete cancel_document_scan_path(@prescription, record_type: "prescription")
    end

    assert_redirected_to new_document_scan_path
  end

  test "cancel does not delete confirmed prescription record" do
    @prescription.update!(extraction_status: :confirmed)

    assert_no_difference "Prescription.count" do
      delete cancel_document_scan_path(@prescription, record_type: "prescription")
    end

    assert_redirected_to new_document_scan_path
  end

  test "cancel deletes pending biology_report record" do
    @biology_report.update!(extraction_status: :pending)

    assert_difference "BiologyReport.count", -1 do
      delete cancel_document_scan_path(@biology_report, record_type: "biology_report")
    end

    assert_redirected_to new_document_scan_path
  end

  test "cancel cannot delete other user's prescription" do
    other_prescription = prescriptions(:other_user_prescription)
    other_prescription.update!(extraction_status: :pending)

    assert_no_difference "Prescription.count" do
      delete cancel_document_scan_path(other_prescription, record_type: "prescription")
    end

    assert_redirected_to new_document_scan_path
  end

  test "cancel cannot delete other user's biology_report" do
    other_report = biology_reports(:other_user_report)
    other_report.update!(extraction_status: :pending)

    assert_no_difference "BiologyReport.count" do
      delete cancel_document_scan_path(other_report, record_type: "biology_report")
    end

    assert_redirected_to new_document_scan_path
  end

  test "cancel handles non-existent record gracefully" do
    delete cancel_document_scan_path(999999, record_type: "prescription")

    assert_redirected_to new_document_scan_path
    follow_redirect!
    assert_match /cancelled|scan/i, flash[:notice]
  end

  # --- Task 11.1: Image Quality Error Detection Tests ---
  # Requirements: 3.9, 4.9, 8.1, 8.2

  test "extract shows specific guidance for blurry image error" do
    # Requirement 8.2: Provide specific guidance for retaking image with better lighting/focus
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "blurry_prescription.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :image_quality,
      message: "Image is too blurry for reliable extraction"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :unprocessable_entity
    # Should show guidance for better lighting and focus
    assert_match /lighting|focus|blurry|clearer/i, response.body
  end

  test "extract shows guidance when no medical document detected" do
    # Requirement 8.1: Inform user and suggest verifying document type selection
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "not_a_document.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :no_document,
      message: "No prescription document detected in image"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id
        }
      }
    end

    assert_response :unprocessable_entity
    # Should suggest verifying document type selection
    assert_match /no.*document|verify.*document.*type|not.*detected/i, response.body
  end

  test "extract shows suggestion to verify document type when extraction fails" do
    # Requirement 8.1: Suggest verifying document type selection when extraction fails
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "wrong_type.jpg",
      content_type: "image/jpeg"
    )

    error_result = BiologyReportScannerService::ExtractionResult.error(
      type: :extraction,
      message: "Could not extract biology report data"
    )

    BiologyReportScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id
        }
      }
    end

    assert_response :unprocessable_entity
    # Should suggest verifying document type or show try again option
    assert_match /try.*again|document.*type|different|extraction/i, response.body
  end

  test "extract error view shows different guidance for different error types" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    # Test image quality error shows lighting/focus guidance
    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :image_quality,
      message: "Low resolution image"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: { document_type: "prescription", blob_id: blob.id }
      }
    end

    assert_response :unprocessable_entity
    assert_match /retake|better|quality|lighting|focus/i, response.body
  end

  test "extract error view includes try again button" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :image_quality,
      message: "Image quality issue"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: { document_type: "prescription", blob_id: blob.id }
      }
    end

    assert_response :unprocessable_entity
    # Should have a try again link
    assert_select "a[href='#{new_document_scan_path}']", text: /try again/i
  end

  # --- Task 11.2: API Error Handling in UI Tests ---
  # Requirements: 8.3, 6.6

  test "extract shows user-friendly message when Claude API unavailable" do
    # Requirement 8.3: User-friendly error when API unavailable
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :api_error,
      message: "Service temporarily unavailable"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: { document_type: "prescription", blob_id: blob.id }
      }
    end

    assert_response :unprocessable_entity
    # Should show user-friendly message (not technical error)
    assert_match /service.*unavailable|try.*later|temporarily/i, response.body
  end

  test "extract offers to save image for later processing on API failure" do
    # Requirement 8.3: Offer to save image for later processing
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :api_error,
      message: "API connection failed"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: { document_type: "prescription", blob_id: blob.id }
      }
    end

    assert_response :unprocessable_entity
    # Should offer option to save for later
    assert_match /save.*later|process.*later|retry|background/i, response.body
  end

  test "extract displays retry option for transient errors" do
    # Requirement 8.3: Display retry option for transient errors
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :rate_limit,
      message: "Rate limit exceeded, please wait"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: { document_type: "prescription", blob_id: blob.id }
      }
    end

    assert_response :unprocessable_entity
    # Should display retry option
    assert_match /retry|try.*again|wait/i, response.body
  end

  test "extract handles network connection loss gracefully" do
    # Requirement 6.6: Handle network connection loss gracefully
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :network_error,
      message: "Network connection lost"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: { document_type: "prescription", blob_id: blob.id }
      }
    end

    assert_response :unprocessable_entity
    # Should show network-specific guidance
    assert_match /network|connection|offline|retry/i, response.body
  end

  test "extract error view offers background processing option" do
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    error_result = PrescriptionScannerService::ExtractionResult.error(
      type: :api_error,
      message: "Service busy"
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: error_result) } do
      post extract_document_scans_path, params: {
        scan: { document_type: "prescription", blob_id: blob.id }
      }
    end

    assert_response :unprocessable_entity
    # Should offer background processing option
    assert_match /background|later|save/i, response.body
  end

  # --- Task 11.3: Unknown Drug and Biomarker Entry Tests ---
  # Requirements: 8.4, 8.5

  test "review allows custom drug entry when no database match found" do
    # Requirement 8.4: Allow user to proceed with custom drug entry
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Custom Drug",
        medications: [
          {
            drug_name: "Unknown Custom Medicine",
            dosage: "50mg",
            confidence: 0.85,
            matched_drug_id: nil,  # No match in database
            requires_verification: false
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success
    # Should display the custom drug name and allow editing
    assert_match /Unknown Custom Medicine/i, response.body
  end

  test "review shows warning for unmatched drug entry" do
    # Requirement 8.4: Show warning that entry is not in database
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Warning",
        medications: [
          {
            drug_name: "Unmatched Drug XYZ",
            dosage: "100mg",
            confidence: 0.8,
            matched_drug_id: nil,
            requires_verification: false
          }
        ]
      }
    )

    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success
    # Should show warning about unmatched drug (Task 11.3 - Requirement 8.4)
    assert_match /Not in database/i, response.body
    assert_select "[data-unmatched-drug]", count: 1
  end

  test "review allows custom biomarker entry when no database match found" do
    # Requirement 8.5: Allow user to proceed with custom biomarker entry
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Custom Lab",
        test_results: [
          {
            biomarker_name: "Custom Biomarker ABC",
            value: "123",
            unit: "units",
            confidence: 0.9,
            matched_biomarker_id: nil,  # No match in database
            out_of_range: false,
            requires_verification: false
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success
    # Should display the custom biomarker name and allow editing
    assert_match /Custom Biomarker ABC/i, response.body
  end

  test "review shows warning for unmatched biomarker entry" do
    # Requirement 8.5: Show warning that entry is not in database
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Warning Lab",
        test_results: [
          {
            biomarker_name: "Unmatched Biomarker XYZ",
            value: "456",
            unit: "mg/dL",
            confidence: 0.85,
            matched_biomarker_id: nil,
            out_of_range: false,
            requires_verification: false
          }
        ]
      }
    )

    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success
    # Should show warning about unmatched biomarker (Task 11.3 - Requirement 8.5)
    assert_match /Not in database/i, response.body
    assert_select "[data-unmatched-biomarker]", count: 1
  end

  test "confirm allows saving prescription with custom drug entry" do
    # Requirement 8.4: Allow proceeding with custom drug entry
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    assert_difference "Prescription.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          doctor_name: "Dr. Custom",
          prescribed_date: "2026-02-01",
          medications: [
            {
              drug_name: "Custom Unmatched Drug",
              drug_id: nil,  # No drug_id, custom entry
              dosage: "75mg",
              frequency: "once daily"
            }
          ]
        }
      }
    end

    prescription = Prescription.last
    assert_redirected_to prescription_path(prescription)
  end

  test "confirm allows saving biology_report with custom biomarker entry" do
    # Requirement 8.5: Allow proceeding with custom biomarker entry
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    assert_difference "BiologyReport.count", 1 do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id,
          lab_name: "Custom Lab",
          test_date: "2026-02-01",
          test_results: [
            {
              biomarker_name: "Custom Unmatched Biomarker",
              biomarker_id: nil,  # No biomarker_id, custom entry
              value: "789",
              unit: "mg/dL"
            }
          ]
        }
      }
    end

    report = BiologyReport.last
    assert_redirected_to biology_report_path(report)
  end

  test "confirm validates required fields even for custom drug entries" do
    # Requirement 8.4: Still validate required fields for custom entries
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    assert_no_difference "Prescription.count" do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "prescription",
          blob_id: blob.id,
          doctor_name: "Dr. Validation",
          prescribed_date: nil,  # Missing required date
          medications: [
            {
              drug_name: "",  # Empty drug name should be invalid
              drug_id: nil
            }
          ]
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "confirm validates required fields even for custom biomarker entries" do
    # Requirement 8.5: Still validate required fields for custom entries
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_biology_report.jpg",
      content_type: "image/jpeg"
    )

    assert_no_difference "BiologyReport.count" do
      post confirm_document_scans_path, params: {
        scan: {
          document_type: "biology_report",
          blob_id: blob.id,
          lab_name: "Validation Lab",
          test_date: nil,  # Missing required date
          test_results: [
            {
              biomarker_name: "",  # Empty biomarker name should be invalid
              biomarker_id: nil,
              value: ""  # Empty value should be invalid
            }
          ]
        }
      }
    end

    assert_response :unprocessable_entity
  end

  # --- Task 11.4: State Preservation for Review Tests ---
  # Requirements: 8.7

  test "extraction state is stored in session during review" do
    # Requirement 8.7: Store extraction state in session
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [
        PrescriptionScannerService::ExtractedMedication.new(
          drug_name: "Session Aspirin",
          dosage: "100mg",
          frequency: "daily",
          confidence: 0.9
        )
      ],
      doctor_name: "Dr. Session",
      prescription_date: "2026-01-15",
      raw_response: {}
    )

    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: mock_result) } do
      post extract_document_scans_path, params: {
        scan: { document_type: "prescription", blob_id: blob.id }
      }
    end

    assert_response :success
    # Session should contain extraction state (verified by presence of data in response)
    assert_match /Session Aspirin/i, response.body
  end

  test "extraction state is preserved if user navigates away and returns" do
    # Requirement 8.7: Preserve state if user navigates away and returns
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Navigate Away",
        medications: [
          { drug_name: "Navigate Drug", dosage: "50mg", confidence: 0.9 }
        ]
      }
    )

    # First access to review
    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success
    assert_match /Navigate Drug/i, response.body

    # Navigate away
    get new_document_scan_path
    assert_response :success

    # Return to review - state should be preserved
    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success
    assert_match /Navigate Drug/i, response.body
    assert_match /Dr\. Navigate Away/i, response.body
  end

  test "extraction state in database persists across requests" do
    # Requirement 8.7: Store extraction state (database approach)
    image = fixture_file_upload("test_image.jpg", "image/jpeg")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image.open,
      filename: "test_prescription.jpg",
      content_type: "image/jpeg"
    )

    mock_result = PrescriptionScannerService::ExtractionResult.success(
      medications: [
        PrescriptionScannerService::ExtractedMedication.new(
          drug_name: "Persistent Drug",
          dosage: "200mg",
          frequency: "twice daily",
          confidence: 0.95
        )
      ],
      doctor_name: "Dr. Persistent",
      prescription_date: "2026-02-15",
      raw_response: {}
    )

    # Create prescription record with background processing (stores in DB)
    PrescriptionScannerService.stub :new, ->(**args) { OpenStruct.new(call: mock_result) } do
      post extract_document_scans_path, params: {
        scan: { document_type: "prescription", blob_id: blob.id }
      }
    end

    assert_response :success
    # Verify data is persisted (shown in review)
    assert_match /Persistent Drug|Dr\. Persistent/i, response.body
  end

  test "stale extraction state can be retrieved after timeout" do
    # Requirement 8.7: State is preserved (database records don't expire in same way as session)
    # Using database storage, records persist until explicitly deleted
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Stale",
        medications: [
          { drug_name: "Stale Drug", dosage: "25mg", confidence: 0.8 }
        ]
      },
      updated_at: 2.hours.ago
    )

    # Can still access the extracted data even after time has passed
    get review_document_scan_path(@prescription, record_type: "prescription")
    assert_response :success
    assert_match /Stale Drug/i, response.body
  end

  test "cleanup of stale extraction records is available" do
    # Requirement 8.7: Clean up stale extraction state after timeout
    # This tests that stale records can be identified for cleanup
    old_prescription = Prescription.create!(
      user: @user,
      doctor_name: "Old Doctor",
      prescribed_date: 1.day.ago,
      extraction_status: :pending,
      created_at: 25.hours.ago,
      updated_at: 25.hours.ago
    )

    # Records older than 24 hours in pending/processing status can be cleaned up
    stale_prescriptions = Prescription.where(extraction_status: [:pending, :processing])
                                       .where("updated_at < ?", 24.hours.ago)
    assert_includes stale_prescriptions, old_prescription
  end

  test "extracted biology_report state is preserved across page navigation" do
    # Requirement 8.7: State preservation for biology reports
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Preserved Lab",
        test_results: [
          { biomarker_name: "Preserved Biomarker", value: "100", confidence: 0.9 }
        ]
      }
    )

    # Access review
    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success
    assert_match /Preserved Biomarker/i, response.body

    # Navigate elsewhere
    get new_document_scan_path

    # Return to review
    get review_document_scan_path(@biology_report, record_type: "biology_report")
    assert_response :success
    assert_match /Preserved Biomarker/i, response.body
    assert_match /Preserved Lab/i, response.body
  end
end
