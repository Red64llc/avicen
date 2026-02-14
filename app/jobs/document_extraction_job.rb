# frozen_string_literal: true

# Background job for processing document extraction asynchronously.
#
# This job handles long-running document extraction operations by:
# 1. Updating record status to processing before extraction
# 2. Routing to appropriate scanner service based on record type
# 3. Storing extraction results in the record's extracted_data column
# 4. Broadcasting status updates via Turbo Streams
#
# Usage:
#   DocumentExtractionJob.perform_later(
#     record_type: "Prescription",
#     record_id: prescription.id,
#     blob_id: prescription.scanned_document.blob.id
#   )
#
# @see PrescriptionScannerService for prescription extraction
# @see BiologyReportScannerService for biology report extraction
class DocumentExtractionJob < ApplicationJob
  queue_as :default

  # Retry on rate limit errors with polynomial backoff (max 3 attempts)
  # Polynomial backoff: 3^attempt seconds (3s, 9s, 27s)
  retry_on PrescriptionScannerService::RateLimitError,
           BiologyReportScannerService::RateLimitError,
           wait: :polynomially_longer,
           attempts: 3 do |job, error|
             handle_final_retry_failure(job, error)
           end

  # Discard on configuration errors (non-retryable)
  discard_on PrescriptionScannerService::ConfigurationError,
             BiologyReportScannerService::ConfigurationError do |job, error|
               handle_discard(job, error)
             end

  # Handle case where record was deleted while job was queued
  discard_on ActiveRecord::RecordNotFound do |job, error|
    Rails.logger.info(
      "DocumentExtractionJob discarded: Record not found " \
      "(type: #{job.arguments.first[:record_type]}, id: #{job.arguments.first[:record_id]})"
    )
  end

  # Execute the document extraction
  #
  # @param record_type [String] "Prescription" or "BiologyReport"
  # @param record_id [Integer] ID of the record to extract
  # @param blob_id [Integer] ID of the Active Storage blob containing the image
  def perform(record_type:, record_id:, blob_id:)
    @record_type = record_type
    @record_id = record_id
    @blob_id = blob_id

    record = find_record
    return unless record

    blob = find_blob
    return unless blob

    # Update status to processing before extraction
    update_status(record, :processing)

    # Execute extraction with appropriate scanner service
    result = execute_extraction(record, blob)

    # Handle result and update record
    process_result(record, result)
  end

  private

  attr_reader :record_type, :record_id, :blob_id

  # Find the record to extract
  #
  # @return [Prescription, BiologyReport, nil]
  # @raise [ActiveRecord::RecordNotFound] if record doesn't exist
  def find_record
    case record_type
    when "Prescription"
      Prescription.find(record_id)
    when "BiologyReport"
      BiologyReport.find(record_id)
    else
      log_error("Unknown record type: #{record_type}")
      nil
    end
  end

  # Find the Active Storage blob
  #
  # @return [ActiveStorage::Blob, nil]
  def find_blob
    ActiveStorage::Blob.find(blob_id)
  rescue ActiveRecord::RecordNotFound
    log_error("Blob not found: #{blob_id}")
    nil
  end

  # Update the extraction status on the record
  #
  # @param record [Prescription, BiologyReport]
  # @param status [Symbol] New extraction status
  def update_status(record, status)
    record.update!(extraction_status: status)
  end

  # Execute extraction using the appropriate scanner service
  #
  # @param record [Prescription, BiologyReport]
  # @param blob [ActiveStorage::Blob]
  # @return [PrescriptionScannerService::ExtractionResult, BiologyReportScannerService::ExtractionResult]
  def execute_extraction(record, blob)
    service_class = scanner_service_for(record_type)
    service_class.new(image_blob: blob).call
  end

  # Get the scanner service class for the record type
  #
  # @param type [String] "Prescription" or "BiologyReport"
  # @return [Class]
  def scanner_service_for(type)
    case type
    when "Prescription"
      PrescriptionScannerService
    when "BiologyReport"
      BiologyReportScannerService
    else
      raise ArgumentError, "Unknown record type: #{type}"
    end
  end

  # Process the extraction result and update the record
  #
  # @param record [Prescription, BiologyReport]
  # @param result [ExtractionResult]
  def process_result(record, result)
    if result.success?
      handle_success(record, result)
    else
      handle_failure(record, result)
    end
  end

  # Handle successful extraction
  #
  # @param record [Prescription, BiologyReport]
  # @param result [ExtractionResult]
  def handle_success(record, result)
    # Store extraction result in extracted_data column
    extracted_data = build_extracted_data(result)

    record.update!(
      extraction_status: :extracted,
      extracted_data: extracted_data
    )

    # Broadcast status update via Turbo Streams
    broadcast_completion(record, :extracted)

    Rails.logger.info(
      "DocumentExtractionJob completed successfully for #{record_type} ##{record_id}"
    )
  end

  # Handle failed extraction
  #
  # @param record [Prescription, BiologyReport]
  # @param result [ExtractionResult]
  def handle_failure(record, result)
    record.update!(
      extraction_status: :failed,
      extracted_data: { error_type: result.error_type, error_message: result.error_message }
    )

    # Broadcast status update via Turbo Streams
    broadcast_completion(record, :failed)

    # Log sanitized error (no medical content)
    log_error(
      "Extraction failed for #{record_type} ##{record_id}: " \
      "type=#{result.error_type}"
    )
  end

  # Build extracted data hash from extraction result
  #
  # @param result [ExtractionResult]
  # @return [Hash]
  def build_extracted_data(result)
    case record_type
    when "Prescription"
      build_prescription_data(result)
    when "BiologyReport"
      build_biology_report_data(result)
    else
      {}
    end
  end

  # Build extracted data hash for prescription
  #
  # @param result [PrescriptionScannerService::ExtractionResult]
  # @return [Hash]
  def build_prescription_data(result)
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
      end,
      raw_response: result.raw_response
    }
  end

  # Build extracted data hash for biology report
  #
  # @param result [BiologyReportScannerService::ExtractionResult]
  # @return [Hash]
  def build_biology_report_data(result)
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
      end,
      raw_response: result.raw_response
    }
  end

  # Broadcast completion status via Turbo Streams
  #
  # @param record [Prescription, BiologyReport]
  # @param status [Symbol] :extracted or :failed
  def broadcast_completion(record, status)
    # Broadcast to user's channel for async notification
    # Uses broadcast_replace_later_to for async notification
    # Handles case where user is no longer on related page gracefully
    target_dom_id = "#{record_type.underscore}_#{record.id}_extraction_status"
    stream_name = extraction_stream_name(record)

    record.broadcast_replace_later_to(
      stream_name,
      target: target_dom_id,
      partial: "document_scans/extraction_status",
      locals: {
        record: record,
        status: status,
        record_type: record_type
      }
    )
  rescue StandardError => e
    # Handle gracefully if user is no longer on related page
    # Turbo Stream broadcasts are fire-and-forget
    Rails.logger.debug("Broadcast failed (user may have navigated away): #{e.message}")
  end

  # Generate stream name for extraction broadcasts
  #
  # @param record [Prescription, BiologyReport]
  # @return [String]
  def extraction_stream_name(record)
    "#{record.user.id}_document_extractions"
  end

  # Handle final retry failure
  #
  # @param job [DocumentExtractionJob]
  # @param error [StandardError]
  def self.handle_final_retry_failure(job, error)
    record_type = job.arguments.first[:record_type]
    record_id = job.arguments.first[:record_id]

    record = case record_type
    when "Prescription"
      Prescription.find_by(id: record_id)
    when "BiologyReport"
      BiologyReport.find_by(id: record_id)
    end

    if record
      record.update!(
        extraction_status: :failed,
        extracted_data: {
          error_type: :rate_limit_exhausted,
          error_message: "Extraction failed after maximum retry attempts"
        }
      )
    end

    Rails.logger.error(
      "DocumentExtractionJob exhausted retries for #{record_type} ##{record_id}"
    )
  end

  # Handle discard on configuration error
  #
  # @param job [DocumentExtractionJob]
  # @param error [StandardError]
  def self.handle_discard(job, error)
    record_type = job.arguments.first[:record_type]
    record_id = job.arguments.first[:record_id]

    record = case record_type
    when "Prescription"
      Prescription.find_by(id: record_id)
    when "BiologyReport"
      BiologyReport.find_by(id: record_id)
    end

    if record
      record.update!(
        extraction_status: :failed,
        extracted_data: {
          error_type: :configuration,
          error_message: "Extraction configuration error (non-retryable)"
        }
      )
    end

    Rails.logger.error(
      "DocumentExtractionJob discarded for #{record_type} ##{record_id}: Configuration error"
    )
  end

  # Log error with sanitized details (no medical content)
  #
  # @param message [String]
  def log_error(message)
    Rails.logger.error("DocumentExtractionJob: #{message}")
  end
end
