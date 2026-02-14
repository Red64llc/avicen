# frozen_string_literal: true

# Service for extracting prescription data from images using Claude Vision API.
#
# Uses RubyLLM gem with vision capabilities to analyze prescription images
# and extract structured medication data including drug names, dosages,
# frequencies, and quantities.
#
# Usage:
#   service = PrescriptionScannerService.new(image_blob: prescription_image_blob)
#   result = service.call
#
#   if result.success?
#     result.medications.each do |med|
#       puts "#{med.drug_name}: #{med.dosage}, #{med.frequency}"
#       puts "  Matched to: #{med.matched_drug&.name}" if med.matched_drug
#       puts "  Needs verification" if med.requires_verification
#     end
#   else
#     puts "Extraction failed: #{result.error_message}"
#   end
#
# @see PrescriptionExtractionSchema for the structured output schema
# @see ImageProcessingService for image resizing before API calls
class PrescriptionScannerService
  # Base error class for prescription scanning errors
  class Error < StandardError; end

  # Raised when API configuration is missing or invalid
  class ConfigurationError < Error; end

  # Raised when API authentication fails
  class AuthenticationError < Error; end

  # Raised when API rate limit is exceeded
  class RateLimitError < Error; end

  # Raised when extraction fails due to parsing or validation errors
  class ExtractionError < Error; end

  # Confidence threshold below which fields require user verification
  CONFIDENCE_THRESHOLD = 0.5

  # Default model for vision capabilities
  DEFAULT_MODEL = "claude-sonnet-4-20250514"

  # Immutable value object representing the extraction result
  class ExtractionResult
    attr_reader :medications, :doctor_name, :prescription_date, :raw_response,
                :error_type, :error_message

    def initialize(success:, medications: [], doctor_name: nil,
                   prescription_date: nil, error_type: nil, error_message: nil,
                   raw_response: nil)
      @success = success
      @medications = medications
      @doctor_name = doctor_name
      @prescription_date = prescription_date
      @error_type = error_type
      @error_message = error_message
      @raw_response = raw_response
      freeze
    end

    def success?
      @success
    end

    def error?
      !@success
    end

    # Factory method for successful extraction results
    #
    # @param medications [Array<ExtractedMedication>] List of extracted medications
    # @param doctor_name [String, nil] Prescribing doctor's name
    # @param prescription_date [String, nil] Date on prescription (YYYY-MM-DD format)
    # @param raw_response [Hash] Raw JSON response for audit
    # @return [ExtractionResult]
    def self.success(medications:, doctor_name:, prescription_date:, raw_response:)
      new(success: true, medications: medications, doctor_name: doctor_name,
          prescription_date: prescription_date, raw_response: raw_response)
    end

    # Factory method for error results
    #
    # @param type [Symbol] Error type (:rate_limit, :authentication, :api_error, :extraction)
    # @param message [String] Human-readable error message
    # @return [ExtractionResult]
    def self.error(type:, message:)
      new(success: false, error_type: type, error_message: message)
    end
  end

  # Immutable data class for individual extracted medication entries
  class ExtractedMedication
    attr_reader :drug_name, :dosage, :frequency, :duration, :quantity,
                :confidence, :matched_drug, :requires_verification,
                :active_ingredients, :rxcui

    def initialize(drug_name:, dosage: nil, frequency: nil, duration: nil,
                   quantity: nil, confidence:, matched_drug: nil,
                   requires_verification: false, active_ingredients: nil, rxcui: nil)
      @drug_name = drug_name
      @dosage = dosage
      @frequency = frequency
      @duration = duration
      @quantity = quantity
      @confidence = confidence
      @matched_drug = matched_drug
      @requires_verification = requires_verification
      @active_ingredients = active_ingredients
      @rxcui = rxcui
      freeze
    end
  end

  # Initialize the prescription scanner service
  #
  # @param image_blob [ActiveStorage::Blob] The prescription image blob
  # @param llm_client [Object, nil] Optional LLM client for testing (defaults to RubyLLM chat)
  def initialize(image_blob:, llm_client: nil)
    @image_blob = image_blob
    @llm_client = llm_client
  end

  # Execute the prescription extraction
  #
  # @return [ExtractionResult] Result containing medications or error information
  def call
    processed_image = process_image
    response = send_to_llm(processed_image)
    parsed_data = parse_response(response.content)
    medications = build_medications(parsed_data)

    ExtractionResult.success(
      medications: medications,
      doctor_name: parsed_data[:doctor_name],
      prescription_date: parsed_data[:prescription_date],
      raw_response: parsed_data
    )
  rescue RubyLLM::RateLimitError => e
    ExtractionResult.error(type: :rate_limit, message: e.message)
  rescue RubyLLM::UnauthorizedError => e
    ExtractionResult.error(type: :authentication, message: e.message)
  rescue RubyLLM::Error => e
    ExtractionResult.error(type: :api_error, message: e.message)
  rescue ExtractionError => e
    ExtractionResult.error(type: :extraction, message: e.message)
  ensure
    cleanup_processed_image(processed_image) if processed_image
  end

  private

  attr_reader :image_blob, :llm_client

  # Process the image for optimal API usage
  #
  # @return [ImageProcessingService::ProcessedImage]
  def process_image
    ImageProcessingService.new(blob: image_blob).call
  end

  # Send the processed image to Claude Vision API
  #
  # @param processed_image [ImageProcessingService::ProcessedImage]
  # @return [Object] LLM response with content
  def send_to_llm(processed_image)
    client = llm_client || default_llm_client
    client.ask(extraction_prompt, with: processed_image.path)
  end

  # Get or create the default LLM client
  #
  # @return [Object] RubyLLM chat client
  def default_llm_client
    @default_llm_client ||= RubyLLM.chat(model: DEFAULT_MODEL)
  end

  # Build the extraction prompt
  #
  # @return [String]
  def extraction_prompt
    <<~PROMPT
      Analyze this prescription image and extract medication information.

      Return a JSON object with exactly these fields:
      - doctor_name: Prescribing doctor's name (string, optional)
      - prescription_date: Date on prescription in YYYY-MM-DD format (string, optional)
      - medications: Array of medication objects with:
        - drug_name: Name of the medication (string, required)
        - dosage: Dosage amount and unit e.g. "500mg" (string, optional)
        - frequency: How often to take e.g. "twice daily" (string, optional)
        - duration: Treatment duration e.g. "7 days" (string, optional)
        - quantity: Number of pills/doses prescribed (string, optional)
        - confidence: Your confidence in this extraction from 0.0 to 1.0 (number, required)

      If you cannot confidently identify a field, omit it or set confidence below 0.5.
      Respond with ONLY valid JSON, no markdown formatting.
    PROMPT
  end

  # Parse the LLM response content, handling markdown code fences
  # Validates response structure against PrescriptionExtractionSchema requirements.
  #
  # @param content [String] Raw response content
  # @return [Hash] Parsed JSON as hash with symbol keys
  # @raise [ExtractionError] If JSON parsing fails or required fields missing
  def parse_response(content)
    json_content = extract_json_from_content(content)
    parsed = JSON.parse(json_content)

    unless parsed.is_a?(Hash)
      raise ExtractionError, "Response is not a JSON object"
    end

    unless parsed.key?("medications") && parsed["medications"].is_a?(Array)
      raise ExtractionError, "Response missing required 'medications' array"
    end

    # Validate each medication against PrescriptionExtractionSchema requirements
    validate_medications_schema(parsed["medications"])

    symbolize_keys_deep(parsed)
  rescue JSON::ParserError => e
    raise ExtractionError, "Failed to parse JSON response: #{e.message}"
  end

  # Validate medications array against PrescriptionExtractionSchema requirements.
  # The schema defines required fields for each medication:
  #   - drug_name: Name of the medication (required)
  #   - confidence: Extraction confidence score 0.0-1.0 (required)
  # Optional fields (dosage, frequency, duration, quantity) are not validated here.
  #
  # @param medications [Array<Hash>] Array of medication hashes from JSON response
  # @raise [ExtractionError] If required fields are missing per PrescriptionExtractionSchema
  # @see PrescriptionExtractionSchema for the authoritative schema definition
  def validate_medications_schema(medications)
    medications.each_with_index do |medication, index|
      unless medication.is_a?(Hash)
        raise ExtractionError, "Medication at index #{index} is not an object"
      end

      # drug_name is required per PrescriptionExtractionSchema
      unless medication.key?("drug_name") && medication["drug_name"].present?
        raise ExtractionError, "Medication at index #{index} missing required 'drug_name' field"
      end

      # confidence is required per PrescriptionExtractionSchema
      unless medication.key?("confidence")
        raise ExtractionError, "Medication at index #{index} missing required 'confidence' field"
      end
    end
  end

  # Extract JSON from content that may be wrapped in markdown code fences
  #
  # @param content [String] Raw content potentially with markdown wrapping
  # @return [String] Clean JSON string
  def extract_json_from_content(content)
    content = content.strip

    # Handle markdown code fence wrapping (```json or ```)
    if content.start_with?("```")
      content = content.sub(/\A```\w*\n?/, "")
      content = content.sub(/\n?```\z/, "")
    end

    content.strip
  end

  # Recursively symbolize hash keys
  #
  # @param obj [Object] Object to process
  # @return [Object] Object with symbolized keys
  def symbolize_keys_deep(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_sym).transform_values { |v| symbolize_keys_deep(v) }
    when Array
      obj.map { |v| symbolize_keys_deep(v) }
    else
      obj
    end
  end

  # Build ExtractedMedication objects from parsed data with drug matching
  #
  # @param parsed_data [Hash] Parsed response data
  # @return [Array<ExtractedMedication>]
  def build_medications(parsed_data)
    medications = parsed_data[:medications] || []

    medications.map do |med_data|
      build_medication(med_data)
    end
  end

  # Build a single ExtractedMedication with drug matching and confidence scoring
  #
  # @param med_data [Hash] Raw medication data from LLM response
  # @return [ExtractedMedication]
  def build_medication(med_data)
    drug_name = med_data[:drug_name]
    confidence = med_data[:confidence] || 0.0

    # Attempt to match drug in local database
    matched_drug = match_drug(drug_name)

    # Extract metadata from matched drug
    active_ingredients = extract_active_ingredients(matched_drug)
    rxcui = matched_drug&.rxcui

    # Determine if verification is required based on confidence
    requires_verification = confidence < CONFIDENCE_THRESHOLD

    ExtractedMedication.new(
      drug_name: drug_name,
      dosage: med_data[:dosage],
      frequency: med_data[:frequency],
      duration: med_data[:duration],
      quantity: med_data[:quantity],
      confidence: confidence,
      matched_drug: matched_drug,
      requires_verification: requires_verification,
      active_ingredients: active_ingredients,
      rxcui: rxcui
    )
  end

  # Match extracted drug name against local Drug database using fuzzy matching
  #
  # @param drug_name [String] Extracted drug name from prescription
  # @return [Drug, nil] Matched drug or nil if no match found
  def match_drug(drug_name)
    return nil if drug_name.blank?

    # Try exact match first (case-insensitive)
    exact_match = Drug.where("LOWER(name) = ?", drug_name.downcase).first
    return exact_match if exact_match

    # Try partial/fuzzy match - search for drug name appearing in database names
    # or database drug names appearing in the extracted name
    partial_matches = Drug.where("LOWER(name) LIKE ?", "%#{drug_name.downcase}%")
    return partial_matches.first if partial_matches.any?

    # Try reverse partial match - extracted name contains database drug name
    # Split extracted name into words and try matching
    drug_name_words = drug_name.split(/\s+/)
    drug_name_words.each do |word|
      next if word.length < 3 # Skip short words

      match = Drug.where("LOWER(name) LIKE ?", "%#{word.downcase}%").first
      return match if match
    end

    nil
  end

  # Extract active ingredients from matched drug
  #
  # @param drug [Drug, nil] Matched drug
  # @return [Array<String>, nil] Active ingredients or nil
  def extract_active_ingredients(drug)
    return nil unless drug&.active_ingredients.present?

    # Parse JSON array if stored as string
    case drug.active_ingredients
    when String
      JSON.parse(drug.active_ingredients)
    when Array
      drug.active_ingredients
    else
      nil
    end
  rescue JSON::ParserError
    nil
  end

  # Clean up temporary processed image file
  #
  # @param processed_image [ImageProcessingService::ProcessedImage, nil]
  def cleanup_processed_image(processed_image)
    return unless processed_image&.path

    File.delete(processed_image.path) if File.exist?(processed_image.path)
  rescue Errno::ENOENT
    # File already deleted, ignore
  end
end
