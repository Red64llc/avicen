# frozen_string_literal: true

# Service for extracting biology report data from images using Claude Vision API.
#
# Uses RubyLLM gem with vision capabilities to analyze lab report images
# and extract structured test result data including biomarker names, values,
# units, and reference ranges.
#
# Usage:
#   service = BiologyReportScannerService.new(image_blob: lab_report_image_blob)
#   result = service.call
#
#   if result.success?
#     result.test_results.each do |test|
#       puts "#{test.biomarker_name}: #{test.value} #{test.unit}"
#       puts "  Matched to: #{test.matched_biomarker&.name}" if test.matched_biomarker
#       puts "  Out of range!" if test.out_of_range
#       puts "  Needs verification" if test.requires_verification
#     end
#   else
#     puts "Extraction failed: #{result.error_message}"
#   end
#
# @see BiologyReportExtractionSchema for the structured output schema
# @see ImageProcessingService for image resizing before API calls
class BiologyReportScannerService
  # Base error class for biology report scanning errors
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
    attr_reader :test_results, :lab_name, :test_date, :raw_response,
                :error_type, :error_message

    def initialize(success:, test_results: [], lab_name: nil,
                   test_date: nil, error_type: nil, error_message: nil,
                   raw_response: nil)
      @success = success
      @test_results = test_results
      @lab_name = lab_name
      @test_date = test_date
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
    # @param test_results [Array<ExtractedTestResult>] List of extracted test results
    # @param lab_name [String, nil] Laboratory name
    # @param test_date [String, nil] Date of the test (YYYY-MM-DD format)
    # @param raw_response [Hash] Raw JSON response for audit
    # @return [ExtractionResult]
    def self.success(test_results:, lab_name:, test_date:, raw_response:)
      new(success: true, test_results: test_results, lab_name: lab_name,
          test_date: test_date, raw_response: raw_response)
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

  # Immutable data class for individual extracted test result entries
  class ExtractedTestResult
    attr_reader :biomarker_name, :value, :unit, :reference_min, :reference_max,
                :confidence, :matched_biomarker, :out_of_range, :requires_verification

    def initialize(biomarker_name:, value:, unit: nil, reference_min: nil,
                   reference_max: nil, confidence:, matched_biomarker: nil,
                   out_of_range: false, requires_verification: false)
      @biomarker_name = biomarker_name
      @value = value
      @unit = unit
      @reference_min = reference_min
      @reference_max = reference_max
      @confidence = confidence
      @matched_biomarker = matched_biomarker
      @out_of_range = out_of_range
      @requires_verification = requires_verification
      freeze
    end
  end

  # Initialize the biology report scanner service
  #
  # @param image_blob [ActiveStorage::Blob] The biology report image blob
  # @param llm_client [Object, nil] Optional LLM client for testing (defaults to RubyLLM chat)
  def initialize(image_blob:, llm_client: nil)
    @image_blob = image_blob
    @llm_client = llm_client
  end

  # Execute the biology report extraction
  #
  # @return [ExtractionResult] Result containing test_results or error information
  def call
    processed_image = process_image
    response = send_to_llm(processed_image)
    parsed_data = parse_response(response.content)
    test_results = build_test_results(parsed_data)

    ExtractionResult.success(
      test_results: test_results,
      lab_name: parsed_data[:lab_name],
      test_date: parsed_data[:test_date],
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
      Analyze this laboratory/biology report image and extract test results.

      Return a JSON object with exactly these fields:
      - lab_name: Name of the laboratory (string, optional)
      - test_date: Date of the test in YYYY-MM-DD format (string, optional)
      - test_results: Array of test result objects with:
        - biomarker_name: Name of the test/biomarker (string, required)
        - value: Measured value as string (string, required)
        - unit: Unit of measurement (string, optional)
        - reference_range: Normal range e.g. "3.5-5.0" (string, optional)
        - confidence: Your confidence in this extraction from 0.0 to 1.0 (number, required)

      If you cannot confidently identify a field, omit it or set confidence below 0.5.
      Respond with ONLY valid JSON, no markdown formatting.
    PROMPT
  end

  # Parse the LLM response content, handling markdown code fences
  # Validates response structure against BiologyReportExtractionSchema requirements.
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

    unless parsed.key?("test_results") && parsed["test_results"].is_a?(Array)
      raise ExtractionError, "Response missing required 'test_results' array"
    end

    # Validate each test result against BiologyReportExtractionSchema requirements
    validate_test_results_schema(parsed["test_results"])

    symbolize_keys_deep(parsed)
  rescue JSON::ParserError => e
    raise ExtractionError, "Failed to parse JSON response: #{e.message}"
  end

  # Validate test_results array against BiologyReportExtractionSchema requirements.
  # The schema defines required fields for each test result:
  #   - biomarker_name: Name of the test/biomarker (required)
  #   - value: Measured value as string (required)
  #   - confidence: Extraction confidence score 0.0-1.0 (required)
  # Optional fields (unit, reference_range) are not validated here.
  #
  # @param test_results [Array<Hash>] Array of test result hashes from JSON response
  # @raise [ExtractionError] If required fields are missing per BiologyReportExtractionSchema
  # @see BiologyReportExtractionSchema for the authoritative schema definition
  def validate_test_results_schema(test_results)
    test_results.each_with_index do |test_result, index|
      unless test_result.is_a?(Hash)
        raise ExtractionError, "Test result at index #{index} is not an object"
      end

      # biomarker_name is required per BiologyReportExtractionSchema
      unless test_result.key?("biomarker_name") && test_result["biomarker_name"].present?
        raise ExtractionError, "Test result at index #{index} missing required 'biomarker_name' field"
      end

      # value is required per BiologyReportExtractionSchema
      unless test_result.key?("value") && test_result["value"].present?
        raise ExtractionError, "Test result at index #{index} missing required 'value' field"
      end

      # confidence is required per BiologyReportExtractionSchema
      unless test_result.key?("confidence")
        raise ExtractionError, "Test result at index #{index} missing required 'confidence' field"
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

  # Build ExtractedTestResult objects from parsed data with biomarker matching
  #
  # @param parsed_data [Hash] Parsed response data
  # @return [Array<ExtractedTestResult>]
  def build_test_results(parsed_data)
    test_results = parsed_data[:test_results] || []

    test_results.map do |result_data|
      build_test_result(result_data)
    end
  end

  # Build a single ExtractedTestResult with biomarker matching and out-of-range detection
  #
  # @param result_data [Hash] Raw test result data from LLM response
  # @return [ExtractedTestResult]
  def build_test_result(result_data)
    biomarker_name = result_data[:biomarker_name]
    value = result_data[:value]
    confidence = result_data[:confidence] || 0.0

    # Attempt to match biomarker in local database
    matched_biomarker = match_biomarker(biomarker_name)

    # Parse reference range from extracted data or use biomarker defaults
    reference_min, reference_max = determine_reference_range(
      result_data[:reference_range],
      matched_biomarker
    )

    # Calculate out-of-range flag based on reference ranges
    out_of_range = calculate_out_of_range(value, reference_min, reference_max)

    # Determine if verification is required based on confidence
    requires_verification = confidence < CONFIDENCE_THRESHOLD

    ExtractedTestResult.new(
      biomarker_name: biomarker_name,
      value: value,
      unit: result_data[:unit],
      reference_min: reference_min,
      reference_max: reference_max,
      confidence: confidence,
      matched_biomarker: matched_biomarker,
      out_of_range: out_of_range,
      requires_verification: requires_verification
    )
  end

  # Match extracted biomarker name against local Biomarker database using fuzzy matching
  #
  # @param biomarker_name [String] Extracted biomarker name from report
  # @return [Biomarker, nil] Matched biomarker or nil if no match found
  def match_biomarker(biomarker_name)
    return nil if biomarker_name.blank?

    # Try exact match first (case-insensitive)
    exact_match = Biomarker.where("LOWER(name) = ?", biomarker_name.downcase).first
    return exact_match if exact_match

    # Try partial/fuzzy match - search for biomarker name appearing in database names
    # or database biomarker names appearing in the extracted name
    partial_matches = Biomarker.where("LOWER(name) LIKE ?", "%#{biomarker_name.downcase}%")
    return partial_matches.first if partial_matches.any?

    # Try reverse partial match - extracted name contains database biomarker name
    # Split extracted name into words and try matching
    biomarker_name_words = biomarker_name.split(/\s+/)
    biomarker_name_words.each do |word|
      next if word.length < 3 # Skip short words

      match = Biomarker.where("LOWER(name) LIKE ?", "%#{word.downcase}%").first
      return match if match
    end

    nil
  end

  # Determine reference range from extracted data or biomarker defaults
  #
  # @param extracted_range [String, nil] Reference range string from extraction (e.g., "70-100")
  # @param matched_biomarker [Biomarker, nil] Matched biomarker with default ranges
  # @return [Array<Float, Float>] [reference_min, reference_max] or [nil, nil]
  def determine_reference_range(extracted_range, matched_biomarker)
    # Try to parse extracted reference range first
    if extracted_range.present?
      parsed = parse_reference_range(extracted_range)
      return parsed if parsed.any?(&:present?)
    end

    # Fall back to matched biomarker defaults
    if matched_biomarker
      return [ matched_biomarker.ref_min, matched_biomarker.ref_max ]
    end

    [ nil, nil ]
  end

  # Parse reference range string into min and max values
  # Handles various formats: "70-100", "70 - 100", "70.0-100.0"
  #
  # @param range_string [String] Reference range string
  # @return [Array<Float, Float>] [min, max] or [nil, nil] if parsing fails
  def parse_reference_range(range_string)
    return [ nil, nil ] if range_string.blank?

    # Match patterns like "70-100", "70 - 100", "70.0-100.0"
    if range_string =~ /^\s*([\d.]+)\s*-\s*([\d.]+)\s*$/
      min = $1.to_f
      max = $2.to_f
      return [ min, max ]
    end

    [ nil, nil ]
  end

  # Calculate whether the value is out of range based on reference ranges
  #
  # @param value [String] Test result value
  # @param reference_min [Float, nil] Minimum reference value
  # @param reference_max [Float, nil] Maximum reference value
  # @return [Boolean] true if value is out of range, false otherwise
  def calculate_out_of_range(value, reference_min, reference_max)
    # Cannot determine out-of-range without reference ranges
    return false if reference_min.nil? || reference_max.nil?

    # Try to parse value as numeric
    numeric_value = parse_numeric_value(value)
    return false if numeric_value.nil?

    # Check if value is within range (inclusive)
    numeric_value < reference_min || numeric_value > reference_max
  end

  # Parse a value string as a numeric value, handling various formats
  #
  # @param value [String] Value string to parse
  # @return [Float, nil] Numeric value or nil if not parseable
  def parse_numeric_value(value)
    return nil if value.blank?

    # Try to extract a numeric value
    # Handles: "95", "95.5", "<10", ">100", "95 mg/dL"
    if value =~ /^[<>]?\s*([\d.]+)/
      return $1.to_f
    end

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
