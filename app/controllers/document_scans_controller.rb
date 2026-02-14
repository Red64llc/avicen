# frozen_string_literal: true

# Controller for handling the document scanning flow.
#
# This controller orchestrates the multi-step document scanning process:
# 1. new     - Capture interface (camera/upload options)
# 2. upload  - Handle direct upload completion, show type selection
# 3. extract - Trigger extraction (sync or background)
# 4. review  - Display extracted data in editable form
# 5. confirm - Create final Prescription or BiologyReport record
#
# All operations are scoped to the authenticated user via Current.user.
#
# @see PrescriptionScannerService for prescription extraction
# @see BiologyReportScannerService for biology report extraction
# @see DocumentExtractionJob for background processing
class DocumentScansController < ApplicationController
  # Valid document types for scanning
  VALID_DOCUMENT_TYPES = %w[prescription biology_report].freeze

  # Image size threshold (2MB) above which background processing is suggested
  # Based on heuristic: images > 2MB typically take > 5 seconds to process
  LARGE_IMAGE_THRESHOLD = 2.megabytes

  # Base extraction time in seconds for processing overhead
  BASE_EXTRACTION_TIME = 2

  # Processing time per megabyte of image data (seconds)
  TIME_PER_MEGABYTE = 1.5

  # GET /document_scans/new
  # Renders capture interface with camera and file upload options
  def new
    # Render the capture interface within a Turbo Frame for seamless navigation
  end

  # Test-only action: renders a standalone camera controller test widget
  # for system test verification. Only available in test environment.
  def camera_test
    raise ActionController::RoutingError, "Not Found" unless Rails.env.test?
    render "document_scans/camera_test"
  end

  # Test-only action: renders a standalone review form controller test widget
  # for system test verification. Only available in test environment.
  def review_form_test
    raise ActionController::RoutingError, "Not Found" unless Rails.env.test?
    render "document_scans/review_form_test"
  end

  # POST /document_scans/upload
  # Handles direct upload completion, shows document type selection
  def upload
    uploaded_image = scan_params[:image]

    unless uploaded_image.present?
      return render_error("Please upload an image file", :unprocessable_entity)
    end

    # Create blob from uploaded file
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: uploaded_image.tempfile,
      filename: uploaded_image.original_filename,
      content_type: uploaded_image.content_type
    )

    # Render type selection view with blob_id
    render :upload
  end

  # GET /document_scans/select_type
  # Displays document type selection for an existing blob
  # Supports back navigation from background_suggestion and other steps (Requirement 6.7)
  def select_type
    @blob_id = params[:blob_id]

    unless @blob_id.present?
      return render_error("Missing image data", :unprocessable_entity)
    end

    @blob = ActiveStorage::Blob.find_by(id: @blob_id)
    unless @blob
      return render_error("Image not found or expired", :unprocessable_entity)
    end

    # Render type selection view (same as upload, but for GET requests)
    render :upload
  end

  # POST /document_scans/extract
  # Triggers extraction, returns processing or review frame
  #
  # Implements extraction decision logic (Requirement 10.1, 10.2):
  # - Checks if extraction might take longer than 5 seconds based on image size
  # - Offers background processing option when threshold exceeded
  # - For sync extraction: calls scanner service directly and renders review
  # - For background extraction: enqueues DocumentExtractionJob and shows processing status
  def extract
    @blob_id = scan_params[:blob_id]
    @document_type = scan_params[:document_type]
    @background = scan_params[:background] == "1"
    @force_sync = scan_params[:force_sync] == "1"

    unless @blob_id.present?
      return render_error("Missing image data", :unprocessable_entity)
    end

    unless valid_document_type?(@document_type)
      return render_error("Invalid document type", :unprocessable_entity)
    end

    @blob = ActiveStorage::Blob.find_by(id: @blob_id)
    unless @blob
      return render_error("Image not found", :unprocessable_entity)
    end

    # Calculate estimated extraction time and determine if threshold exceeded
    @estimated_time = estimate_extraction_time(@blob.byte_size)
    @exceeds_threshold = extraction_exceeds_threshold?(@blob.byte_size)

    if @background
      # User explicitly requested background processing
      process_background_extraction
    elsif @force_sync
      # User chose to wait despite large image - proceed with sync extraction
      process_sync_extraction
    elsif @exceeds_threshold
      # Large image - suggest background processing option
      render_background_suggestion
    else
      # Small image - proceed with synchronous extraction
      process_sync_extraction
    end
  end

  # GET /document_scans/:id/review
  # Shows editable review form with extracted data
  def review
    @record_type = params[:record_type]
    @record = find_scoped_record(@record_type, params[:id])

    unless @record
      return render_not_found
    end

    unless @record.extraction_extracted?
      return render_error(
        "Record must have extracted data to review",
        :unprocessable_entity
      )
    end

    @extracted_data = (@record.extracted_data || {}).deep_symbolize_keys
    render :review
  end

  # POST /document_scans/confirm
  # Creates Prescription or BiologyReport from confirmed data
  def confirm
    @document_type = scan_params[:document_type]
    @blob_id = scan_params[:blob_id]

    unless valid_document_type?(@document_type)
      return render_error("Invalid document type", :unprocessable_entity)
    end

    @blob = ActiveStorage::Blob.find_by(id: @blob_id)

    case @document_type
    when "prescription"
      create_prescription_from_scan
    when "biology_report"
      create_biology_report_from_scan
    end
  end

  # DELETE /document_scans/:id/cancel
  # Cancels and discards extracted data, optionally deleting pending records
  # For background extractions, this allows cleanup of records that were created
  # but never confirmed by the user.
  #
  # Requirement 5.7: On cancel, discard extracted data and return to scanning interface
  def cancel
    record_type = params[:record_type]
    record = find_scoped_record(record_type, params[:id])

    if record
      # Only allow cancellation of non-confirmed records
      unless record.extraction_confirmed?
        record.destroy
      end
    end

    redirect_to new_document_scan_path, notice: "Scan cancelled. You can start a new document scan."
  end

  private

  # Strong parameters for scan operations
  def scan_params
    params.require(:scan).permit(
      :image,
      :document_type,
      :blob_id,
      :background,
      :force_sync,
      :doctor_name,
      :prescribed_date,
      :lab_name,
      :test_date,
      :notes,
      medications: [ :drug_name, :dosage, :frequency, :duration, :quantity, :drug_id ],
      test_results: [ :biomarker_name, :value, :unit, :ref_min, :ref_max, :biomarker_id ]
    )
  end

  # Validate document type is one of the allowed values
  #
  # @param type [String] Document type to validate
  # @return [Boolean]
  def valid_document_type?(type)
    VALID_DOCUMENT_TYPES.include?(type)
  end

  # Check if extraction might take longer than 5 seconds based on image size
  # Uses heuristic: images > 2MB typically exceed the 5 second threshold
  #
  # @param byte_size [Integer] Image size in bytes
  # @return [Boolean] True if extraction is expected to exceed 5 seconds
  def extraction_exceeds_threshold?(byte_size)
    byte_size >= LARGE_IMAGE_THRESHOLD
  end

  # Estimate extraction time in seconds based on image size
  # Formula: base time + (megabytes * time per megabyte)
  #
  # @param byte_size [Integer] Image size in bytes
  # @return [Float] Estimated time in seconds
  def estimate_extraction_time(byte_size)
    megabytes = byte_size.to_f / 1.megabyte
    BASE_EXTRACTION_TIME + (megabytes * TIME_PER_MEGABYTE)
  end

  # Find a record scoped to the current user
  #
  # @param record_type [String] "prescription" or "biology_report"
  # @param id [Integer] Record ID
  # @return [Prescription, BiologyReport, nil]
  def find_scoped_record(record_type, id)
    case record_type
    when "prescription"
      Current.user.prescriptions.find_by(id: id)
    when "biology_report"
      Current.user.biology_reports.find_by(id: id)
    else
      nil
    end
  end

  # Render background processing suggestion for large images
  # Shows estimated time and offers option to process in background
  def render_background_suggestion
    render :background_suggestion
  end

  # Process synchronous extraction
  def process_sync_extraction
    service_class = scanner_service_for(@document_type)
    result = service_class.new(image_blob: @blob).call

    if result.success?
      @extraction_result = result
      @extracted_data = build_extracted_data(result)
      render :extract_success
    else
      render_extraction_error(result)
    end
  end

  # Process background extraction by enqueuing job
  def process_background_extraction
    # Create a pending record to track extraction status
    @record = create_pending_record(@document_type, @blob)

    # Enqueue the extraction job
    DocumentExtractionJob.perform_later(
      record_type: @document_type.classify,
      record_id: @record.id,
      blob_id: @blob.id
    )

    render :processing
  end

  # Get the scanner service class for a document type
  #
  # @param type [String] "prescription" or "biology_report"
  # @return [Class]
  def scanner_service_for(type)
    case type
    when "prescription"
      PrescriptionScannerService
    when "biology_report"
      BiologyReportScannerService
    else
      raise ArgumentError, "Unknown document type: #{type}"
    end
  end

  # Build extracted data hash from extraction result
  #
  # @param result [ExtractionResult]
  # @return [Hash]
  def build_extracted_data(result)
    case @document_type
    when "prescription"
      {
        doctor_name: result.doctor_name,
        prescription_date: result.prescription_date,
        medications: result.medications.map do |med|
          {
            drug_name: med.drug_name,
            dosage: med.dosage,
            frequency: med.frequency,
            duration: med.duration,
            quantity: med.quantity,
            confidence: med.confidence,
            matched_drug_id: med.matched_drug&.id,
            requires_verification: med.requires_verification
          }
        end
      }
    when "biology_report"
      {
        lab_name: result.lab_name,
        test_date: result.test_date,
        test_results: result.test_results.map do |test|
          {
            biomarker_name: test.biomarker_name,
            value: test.value,
            unit: test.unit,
            reference_min: test.reference_min,
            reference_max: test.reference_max,
            confidence: test.confidence,
            matched_biomarker_id: test.matched_biomarker&.id,
            out_of_range: test.out_of_range,
            requires_verification: test.requires_verification
          }
        end
      }
    else
      {}
    end
  end

  # Create a pending record for background extraction
  #
  # @param type [String] Document type
  # @param blob [ActiveStorage::Blob] Image blob
  # @return [Prescription, BiologyReport]
  def create_pending_record(type, blob)
    case type
    when "prescription"
      record = Current.user.prescriptions.create!(
        prescribed_date: Date.current,
        extraction_status: :pending
      )
      record.scanned_document.attach(blob)
      record
    when "biology_report"
      record = Current.user.biology_reports.create!(
        test_date: Date.current,
        extraction_status: :pending
      )
      record.document.attach(blob)
      record
    end
  end

  # Create prescription from confirmed scan data
  def create_prescription_from_scan
    @prescription = Current.user.prescriptions.build(
      doctor_name: scan_params[:doctor_name],
      prescribed_date: scan_params[:prescribed_date],
      notes: scan_params[:notes],
      extraction_status: :confirmed,
      extracted_data: build_confirmed_data
    )

    # Attach scanned document
    @prescription.scanned_document.attach(@blob) if @blob

    if @prescription.save
      # Create medications from confirmed data
      create_medications_from_scan(@prescription)
      redirect_to @prescription, notice: "Prescription was successfully created from scan."
    else
      @blob_id = @blob&.id
      @extracted_data = build_confirmed_data
      render :confirm_prescription, status: :unprocessable_entity
    end
  end

  # Create biology report from confirmed scan data
  def create_biology_report_from_scan
    @biology_report = Current.user.biology_reports.build(
      lab_name: scan_params[:lab_name],
      test_date: scan_params[:test_date],
      notes: scan_params[:notes],
      extraction_status: :confirmed,
      extracted_data: build_confirmed_data
    )

    # Attach scanned document
    @biology_report.document.attach(@blob) if @blob

    if @biology_report.save
      # Create test results from confirmed data
      create_test_results_from_scan(@biology_report)
      redirect_to @biology_report, notice: "Biology report was successfully created from scan."
    else
      @blob_id = @blob&.id
      @extracted_data = build_confirmed_data
      render :confirm_biology_report, status: :unprocessable_entity
    end
  end

  # Create medications from scan params
  #
  # @param prescription [Prescription]
  def create_medications_from_scan(prescription)
    medications_params = scan_params[:medications] || []

    medications_params.each do |med_params|
      next if med_params[:drug_name].blank?

      drug = find_or_create_drug(med_params)
      next unless drug # Skip if drug not found (can add manually later)

      prescription.medications.create!(
        drug: drug,
        dosage: med_params[:dosage] || "As prescribed",
        form: "tablet", # Default form, user can edit later
        frequency: med_params[:frequency],
        active: true
      )
    end
  end

  # Create test results from scan params
  #
  # @param biology_report [BiologyReport]
  def create_test_results_from_scan(biology_report)
    test_results_params = scan_params[:test_results] || []

    test_results_params.each do |result_params|
      next if result_params[:biomarker_name].blank?

      biomarker = find_or_create_biomarker(result_params)
      next unless biomarker # Skip if biomarker not found (can add manually later)

      biology_report.test_results.create!(
        biomarker: biomarker,
        value: result_params[:value].to_f,
        unit: result_params[:unit] || biomarker.unit || "units",
        ref_min: result_params[:ref_min]&.to_f,
        ref_max: result_params[:ref_max]&.to_f
      )
    end
  end

  # Find existing drug or use default/nil
  #
  # @param params [Hash] Medication params
  # @return [Drug, nil]
  def find_or_create_drug(params)
    return Drug.find_by(id: params[:drug_id]) if params[:drug_id].present?

    # Try to find by name
    Drug.where("LOWER(name) = ?", params[:drug_name].to_s.downcase).first
  end

  # Find existing biomarker or use default/nil
  #
  # @param params [Hash] Test result params
  # @return [Biomarker, nil]
  def find_or_create_biomarker(params)
    return Biomarker.find_by(id: params[:biomarker_id]) if params[:biomarker_id].present?

    # Try to find by name
    Biomarker.where("LOWER(name) = ?", params[:biomarker_name].to_s.downcase).first
  end

  # Build confirmed data hash from scan params
  #
  # @return [Hash]
  def build_confirmed_data
    case @document_type
    when "prescription"
      {
        doctor_name: scan_params[:doctor_name],
        prescription_date: scan_params[:prescribed_date],
        medications: scan_params[:medications]&.to_a || []
      }
    when "biology_report"
      {
        lab_name: scan_params[:lab_name],
        test_date: scan_params[:test_date],
        test_results: scan_params[:test_results]&.to_a || []
      }
    else
      {}
    end
  end

  # Render extraction error with appropriate message
  #
  # @param result [ExtractionResult]
  def render_extraction_error(result)
    @error_type = result.error_type
    @error_message = result.error_message

    render :extract_error, status: :unprocessable_entity
  end

  # Render a generic error response
  #
  # @param message [String] Error message
  # @param status [Symbol] HTTP status
  def render_error(message, status)
    @error_message = message
    respond_to do |format|
      format.html { render :error, status: status }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("document_scan_flow", partial: "document_scans/error", locals: { message: message }), status: status }
    end
  end

  # Render 404 not found response
  def render_not_found
    respond_to do |format|
      format.html { render file: Rails.public_path.join("404.html"), status: :not_found, layout: false }
      format.turbo_stream { head :not_found }
    end
  end
end
