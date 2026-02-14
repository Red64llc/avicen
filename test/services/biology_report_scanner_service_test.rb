# frozen_string_literal: true

require "test_helper"

class BiologyReportScannerServiceTest < ActiveSupport::TestCase
  setup do
    @glucose = biomarkers(:glucose)
    @hemoglobin = biomarkers(:hemoglobin)
    @tsh = biomarkers(:tsh)
    @user = users(:one)

    # Create a mock blob for testing
    @mock_blob = create_mock_blob

    # Stub ImageProcessingService to avoid actual image processing in tests
    @processed_image_path = "/tmp/test_processed_biology_image.jpg"
    @mock_processed_image = ImageProcessingService::ProcessedImage.new(
      path: @processed_image_path,
      width: 1000,
      height: 800,
      content_type: "image/jpeg"
    )

    # Create the mock file so cleanup doesn't fail
    File.write(@processed_image_path, "mock image data") unless File.exist?(@processed_image_path)
  end

  teardown do
    # Clean up mock processed image file
    File.delete(@processed_image_path) if File.exist?(@processed_image_path)
  end

  # --- Error Hierarchy Tests (Task 6.1) ---

  test "defines Error base class" do
    assert_kind_of Class, BiologyReportScannerService::Error
    assert BiologyReportScannerService::Error < StandardError
  end

  test "defines ConfigurationError" do
    assert_kind_of Class, BiologyReportScannerService::ConfigurationError
    assert BiologyReportScannerService::ConfigurationError < BiologyReportScannerService::Error
  end

  test "defines AuthenticationError" do
    assert_kind_of Class, BiologyReportScannerService::AuthenticationError
    assert BiologyReportScannerService::AuthenticationError < BiologyReportScannerService::Error
  end

  test "defines RateLimitError" do
    assert_kind_of Class, BiologyReportScannerService::RateLimitError
    assert BiologyReportScannerService::RateLimitError < BiologyReportScannerService::Error
  end

  test "defines ExtractionError" do
    assert_kind_of Class, BiologyReportScannerService::ExtractionError
    assert BiologyReportScannerService::ExtractionError < BiologyReportScannerService::Error
  end

  # --- ExtractionResult Value Object Tests (Task 6.1) ---

  test "ExtractionResult.success creates successful result" do
    test_results = [ build_extracted_test_result(biomarker_name: "Glucose") ]
    result = BiologyReportScannerService::ExtractionResult.success(
      test_results: test_results,
      lab_name: "Quest Diagnostics",
      test_date: "2026-01-15",
      raw_response: { test: "data" }
    )

    assert result.success?
    assert_not result.error?
    assert_equal test_results, result.test_results
    assert_equal "Quest Diagnostics", result.lab_name
    assert_equal "2026-01-15", result.test_date
    assert_equal({ test: "data" }, result.raw_response)
  end

  test "ExtractionResult.error creates error result" do
    result = BiologyReportScannerService::ExtractionResult.error(
      type: :api_error,
      message: "API returned 500"
    )

    assert result.error?
    assert_not result.success?
    assert_equal :api_error, result.error_type
    assert_equal "API returned 500", result.error_message
  end

  test "ExtractionResult is immutable" do
    result = BiologyReportScannerService::ExtractionResult.success(
      test_results: [],
      lab_name: "Lab Corp",
      test_date: "2026-01-15",
      raw_response: {}
    )

    assert result.frozen?
  end

  # --- ExtractedTestResult Data Class Tests (Task 6.1) ---

  test "ExtractedTestResult stores all test result fields" do
    test_result = BiologyReportScannerService::ExtractedTestResult.new(
      biomarker_name: "Glucose",
      value: "95",
      unit: "mg/dL",
      reference_min: 70.0,
      reference_max: 100.0,
      confidence: 0.95,
      matched_biomarker: @glucose,
      out_of_range: false,
      requires_verification: false
    )

    assert_equal "Glucose", test_result.biomarker_name
    assert_equal "95", test_result.value
    assert_equal "mg/dL", test_result.unit
    assert_equal 70.0, test_result.reference_min
    assert_equal 100.0, test_result.reference_max
    assert_equal 0.95, test_result.confidence
    assert_equal @glucose, test_result.matched_biomarker
    assert_equal false, test_result.out_of_range
    assert_equal false, test_result.requires_verification
  end

  test "ExtractedTestResult is immutable" do
    test_result = build_extracted_test_result(biomarker_name: "Glucose")
    assert test_result.frozen?
  end

  test "ExtractedTestResult includes out_of_range flag" do
    test_result = BiologyReportScannerService::ExtractedTestResult.new(
      biomarker_name: "Glucose",
      value: "150",
      unit: "mg/dL",
      reference_min: 70.0,
      reference_max: 100.0,
      confidence: 0.9,
      out_of_range: true
    )

    assert test_result.out_of_range
  end

  # --- Constructor Tests (Task 6.1) ---

  test "accepts image blob in constructor" do
    service = BiologyReportScannerService.new(image_blob: @mock_blob)
    assert_not_nil service
  end

  test "accepts optional llm_client for testing" do
    mock_client = Object.new
    service = BiologyReportScannerService.new(image_blob: @mock_blob, llm_client: mock_client)
    assert_not_nil service
  end

  # --- Successful Extraction Tests (Task 6.2) ---

  test "extracts single test result from biology report image" do
    mock_response = build_mock_llm_response(
      lab_name: "Quest Diagnostics",
      test_date: "2026-01-15",
      test_results: [
        { biomarker_name: "Glucose", value: "95", unit: "mg/dL", reference_range: "70-100", confidence: 0.95 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_equal 1, result.test_results.length
      assert_equal "Glucose", result.test_results.first.biomarker_name
      assert_equal "95", result.test_results.first.value
      assert_equal "Quest Diagnostics", result.lab_name
    end
  end

  test "extracts multiple test results from single biology report" do
    mock_response = build_mock_llm_response(
      lab_name: "LabCorp",
      test_date: "2026-02-01",
      test_results: [
        { biomarker_name: "Glucose", value: "95", unit: "mg/dL", confidence: 0.9 },
        { biomarker_name: "Hemoglobin", value: "14.5", unit: "g/dL", confidence: 0.85 },
        { biomarker_name: "TSH", value: "2.5", unit: "mIU/L", confidence: 0.88 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_equal 3, result.test_results.length
      assert_equal "Glucose", result.test_results[0].biomarker_name
      assert_equal "Hemoglobin", result.test_results[1].biomarker_name
      assert_equal "TSH", result.test_results[2].biomarker_name
    end
  end

  test "includes raw response in result for audit" do
    mock_response = build_mock_llm_response(
      test_results: [ { biomarker_name: "Glucose", value: "95", confidence: 0.9 } ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_not_nil result.raw_response
    end
  end

  # --- JSON Parsing Tests (Task 6.2) ---

  test "handles JSON response wrapped in markdown code fence" do
    json_content = {
      lab_name: "Quest Diagnostics",
      test_date: "2026-01-15",
      test_results: [
        { biomarker_name: "Glucose", value: "95", confidence: 0.9 }
      ]
    }.to_json

    markdown_wrapped = "```json\n#{json_content}\n```"

    mock_client = mock_llm_client_with_raw_content(markdown_wrapped)

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal "Quest Diagnostics", result.lab_name
      assert_equal 1, result.test_results.length
    end
  end

  test "handles JSON response without markdown fence" do
    json_content = {
      lab_name: "LabCorp",
      test_results: [ { biomarker_name: "Hemoglobin", value: "14.0", confidence: 0.85 } ]
    }.to_json

    mock_client = mock_llm_client_with_raw_content(json_content)

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal "LabCorp", result.lab_name
    end
  end

  test "handles markdown fence with language specifier" do
    json_content = {
      test_results: [ { biomarker_name: "Glucose", value: "95", confidence: 0.9 } ]
    }.to_json

    markdown_wrapped = "```json\n#{json_content}\n```"

    mock_client = mock_llm_client_with_raw_content(markdown_wrapped)

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
    end
  end

  test "handles markdown fence without language specifier" do
    json_content = {
      test_results: [ { biomarker_name: "Glucose", value: "95", confidence: 0.9 } ]
    }.to_json

    markdown_wrapped = "```\n#{json_content}\n```"

    mock_client = mock_llm_client_with_raw_content(markdown_wrapped)

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal 1, result.test_results.length
    end
  end

  # --- Biomarker Matching Tests (Task 6.3) ---

  test "matches extracted biomarker names against local Biomarker database" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "95", unit: "mg/dL", confidence: 0.95 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      assert_equal @glucose, test_result.matched_biomarker
    end
  end

  test "uses fuzzy matching for biomarker name variations" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Fasting Glucose Level", value: "95", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      assert_equal @glucose, test_result.matched_biomarker
    end
  end

  test "sets matched_biomarker to nil when no match found" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Unknown Mystery Biomarker XYZ", value: "123", confidence: 0.8 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      assert_nil test_result.matched_biomarker
    end
  end

  test "matches biomarker with case-insensitive exact match" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "GLUCOSE", value: "95", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      assert_equal @glucose, test_result.matched_biomarker
    end
  end

  test "populates default reference ranges from matched biomarker if not extracted" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "95", confidence: 0.9 }
        # No reference_range provided
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      # Should use default ranges from matched biomarker (glucose: 70-100)
      assert_equal 70.0, test_result.reference_min
      assert_equal 100.0, test_result.reference_max
    end
  end

  test "uses extracted reference range over biomarker defaults when provided" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "95", reference_range: "65-110", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      # Should use extracted ranges (65-110) not biomarker defaults (70-100)
      assert_equal 65.0, test_result.reference_min
      assert_equal 110.0, test_result.reference_max
    end
  end

  test "matches multiple biomarkers with different match outcomes" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "95", confidence: 0.95 },
        { biomarker_name: "Hemoglobin", value: "14.5", confidence: 0.88 },
        { biomarker_name: "Nonexistent Biomarker ABC", value: "123", confidence: 0.7 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_equal 3, result.test_results.length

      # First test result should match Glucose
      assert_equal @glucose, result.test_results[0].matched_biomarker

      # Second test result should match Hemoglobin
      assert_equal @hemoglobin, result.test_results[1].matched_biomarker

      # Third test result should have no match
      assert_nil result.test_results[2].matched_biomarker
    end
  end

  # --- Out-of-Range Detection Tests (Task 6.3) ---

  test "flags value as out of range when above reference max" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "150", unit: "mg/dL", reference_range: "70-100", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      assert test_result.out_of_range
    end
  end

  test "flags value as out of range when below reference min" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "50", unit: "mg/dL", reference_range: "70-100", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      assert test_result.out_of_range
    end
  end

  test "does not flag value within reference range" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "85", unit: "mg/dL", reference_range: "70-100", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      assert_not test_result.out_of_range
    end
  end

  test "uses biomarker default ranges for out-of-range detection when extracted range missing" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "150", confidence: 0.9 }
        # No reference_range provided, should use biomarker defaults (70-100)
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      # Value 150 is above glucose ref_max of 100, should be flagged
      assert test_result.out_of_range
    end
  end

  test "does not flag out of range when no reference range available" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Unknown Biomarker", value: "999", confidence: 0.8 }
        # No match, no reference range
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      # Cannot determine out-of-range without reference ranges
      assert_not test_result.out_of_range
    end
  end

  test "handles edge case values at reference boundaries" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "70", reference_range: "70-100", confidence: 0.9 },
        { biomarker_name: "Hemoglobin", value: "17.5", reference_range: "13.5-17.5", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      # Value at min boundary (70) should NOT be out of range
      assert_not result.test_results[0].out_of_range
      # Value at max boundary (17.5) should NOT be out of range
      assert_not result.test_results[1].out_of_range
    end
  end

  test "handles non-numeric values gracefully for out-of-range detection" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "Positive", reference_range: "70-100", confidence: 0.7 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      # Non-numeric value cannot be compared, should not be flagged
      assert_not test_result.out_of_range
    end
  end

  # --- Confidence Scoring Tests (Task 6.3) ---

  test "flags test result with low confidence as requiring verification" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "95", confidence: 0.4 } # Below 0.5 threshold
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      assert test_result.requires_verification
    end
  end

  test "does not flag test result with high confidence" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "95", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      test_result = result.test_results.first
      assert_not test_result.requires_verification
    end
  end

  test "uses confidence threshold of 0.5 for verification flag" do
    mock_response = build_mock_llm_response(
      test_results: [
        { biomarker_name: "Glucose", value: "95", confidence: 0.5 }, # Exactly at threshold
        { biomarker_name: "Hemoglobin", value: "14.0", confidence: 0.49 } # Just below threshold
      ]
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_not result.test_results[0].requires_verification # 0.5 is OK
      assert result.test_results[1].requires_verification # 0.49 needs verification
    end
  end

  # --- Error Handling Tests (Task 6.4) ---

  test "returns error result on rate limit error" do
    mock_client = mock_llm_client_that_raises(RubyLLM::RateLimitError.new(nil))

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :rate_limit, result.error_type
    end
  end

  test "returns error result on rate limit error with message" do
    mock_client = mock_llm_client_that_raises(
      RubyLLM::RateLimitError.new(OpenStruct.new(body: "Rate limit exceeded. Please retry after 60 seconds."))
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :rate_limit, result.error_type
      assert_not_nil result.error_message
    end
  end

  test "returns error result on authentication error" do
    mock_client = mock_llm_client_that_raises(RubyLLM::UnauthorizedError.new(nil))

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :authentication, result.error_type
    end
  end

  test "returns error result on API error" do
    mock_client = mock_llm_client_that_raises(RubyLLM::Error.new(nil))

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :api_error, result.error_type
    end
  end

  test "returns error result on JSON parse failure" do
    mock_client = mock_llm_client_with_raw_content("not valid json at all")

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
    end
  end

  test "returns error result when response missing required test_results field" do
    mock_client = mock_llm_client_with_raw_content('{"lab_name": "Quest"}')

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
    end
  end

  # --- Schema Validation Tests (Task 6.4) ---

  test "returns error when test result missing required biomarker_name field" do
    mock_client = mock_llm_client_with_raw_content(
      '{"test_results": [{"value": "95", "confidence": 0.9}]}'
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
      assert_match(/biomarker_name/i, result.error_message)
    end
  end

  test "returns error when test result missing required value field" do
    mock_client = mock_llm_client_with_raw_content(
      '{"test_results": [{"biomarker_name": "Glucose", "confidence": 0.9}]}'
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
      assert_match(/value/i, result.error_message)
    end
  end

  test "returns error when test result missing required confidence field" do
    mock_client = mock_llm_client_with_raw_content(
      '{"test_results": [{"biomarker_name": "Glucose", "value": "95"}]}'
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
      assert_match(/confidence/i, result.error_message)
    end
  end

  test "handles test result with all optional fields missing except required ones" do
    mock_client = mock_llm_client_with_raw_content(
      '{"test_results": [{"biomarker_name": "Glucose", "value": "95", "confidence": 0.9}]}'
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal 1, result.test_results.length
      test_result = result.test_results.first
      assert_equal "Glucose", test_result.biomarker_name
      assert_equal "95", test_result.value
      assert_equal 0.9, test_result.confidence
      assert_nil test_result.unit
    end
  end

  test "handles empty test_results array" do
    mock_client = mock_llm_client_with_raw_content(
      '{"lab_name": "Quest", "test_results": []}'
    )

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      # Empty test_results array should still succeed - it's valid JSON
      # The caller can decide how to handle empty extractions
      assert result.success?
      assert_equal 0, result.test_results.length
    end
  end

  # --- Sample Biology Report JSON Tests (Task 6.4) ---

  test "extracts data from realistic biology report JSON response" do
    # Simulates a realistic response from Claude Vision API
    realistic_response = {
      lab_name: "Quest Diagnostics",
      test_date: "2026-02-10",
      test_results: [
        {
          biomarker_name: "Fasting Glucose",
          value: "92",
          unit: "mg/dL",
          reference_range: "70-100",
          confidence: 0.95
        },
        {
          biomarker_name: "Hemoglobin",
          value: "14.8",
          unit: "g/dL",
          reference_range: "13.5-17.5",
          confidence: 0.92
        },
        {
          biomarker_name: "TSH",
          value: "2.1",
          unit: "mIU/L",
          reference_range: "0.4-4.0",
          confidence: 0.88
        }
      ]
    }.to_json

    mock_client = mock_llm_client_with_raw_content(realistic_response)

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal "Quest Diagnostics", result.lab_name
      assert_equal "2026-02-10", result.test_date
      assert_equal 3, result.test_results.length

      # First test result - Glucose
      glucose_result = result.test_results[0]
      assert_equal "Fasting Glucose", glucose_result.biomarker_name
      assert_equal "92", glucose_result.value
      assert_equal "mg/dL", glucose_result.unit
      assert_equal @glucose, glucose_result.matched_biomarker
      assert_not glucose_result.out_of_range
      assert_not glucose_result.requires_verification

      # Second test result - Hemoglobin
      hgb_result = result.test_results[1]
      assert_equal @hemoglobin, hgb_result.matched_biomarker
      assert_not hgb_result.out_of_range

      # Third test result - TSH
      tsh_result = result.test_results[2]
      assert_equal @tsh, tsh_result.matched_biomarker
    end
  end

  test "handles response with mixed in-range and out-of-range values" do
    response_with_mixed_ranges = {
      lab_name: "LabCorp",
      test_results: [
        { biomarker_name: "Glucose", value: "85", reference_range: "70-100", confidence: 0.9 },  # In range
        { biomarker_name: "Glucose", value: "150", reference_range: "70-100", confidence: 0.9 }, # High
        { biomarker_name: "Hemoglobin", value: "10.0", reference_range: "13.5-17.5", confidence: 0.85 } # Low
      ]
    }.to_json

    mock_client = mock_llm_client_with_raw_content(response_with_mixed_ranges)

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?

      # First result - in range
      assert_not result.test_results[0].out_of_range

      # Second result - high (out of range)
      assert result.test_results[1].out_of_range

      # Third result - low (out of range)
      assert result.test_results[2].out_of_range
    end
  end

  test "parses various reference range formats" do
    response_with_various_formats = {
      test_results: [
        { biomarker_name: "Test1", value: "50", reference_range: "40-60", confidence: 0.9 },
        { biomarker_name: "Test2", value: "50", reference_range: "40 - 60", confidence: 0.9 },
        { biomarker_name: "Test3", value: "50", reference_range: "40.0-60.0", confidence: 0.9 }
      ]
    }.to_json

    mock_client = mock_llm_client_with_raw_content(response_with_various_formats)

    stub_image_processing do
      service = BiologyReportScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      # All values should be within range (40-60)
      result.test_results.each do |test_result|
        assert_not test_result.out_of_range, "Test result #{test_result.biomarker_name} should be in range"
      end
    end
  end

  private

  def create_mock_blob
    # Create a minimal mock blob that responds to necessary methods
    mock_blob = Object.new
    def mock_blob.open
      tempfile = Tempfile.new([ "test_image", ".jpg" ])
      tempfile.binmode
      # Write minimal JPEG header
      tempfile.write("\xFF\xD8\xFF\xE0\x00\x10JFIF")
      tempfile.rewind
      yield tempfile
    ensure
      tempfile&.close
      tempfile&.unlink
    end

    def mock_blob.content_type
      "image/jpeg"
    end

    mock_blob
  end

  def build_extracted_test_result(attrs = {})
    defaults = {
      biomarker_name: "Test Biomarker",
      value: "100",
      unit: nil,
      reference_min: nil,
      reference_max: nil,
      confidence: 0.9,
      matched_biomarker: nil,
      out_of_range: false,
      requires_verification: false
    }
    BiologyReportScannerService::ExtractedTestResult.new(**defaults.merge(attrs))
  end

  def build_mock_llm_response(attrs = {})
    {
      lab_name: attrs[:lab_name],
      test_date: attrs[:test_date],
      test_results: attrs[:test_results] || []
    }
  end

  def mock_llm_client(response_data)
    mock = Object.new
    response_data_capture = response_data

    mock.define_singleton_method(:ask) do |*args, **kwargs|
      response = Object.new
      response.define_singleton_method(:content) { response_data_capture.to_json }
      response
    end

    mock
  end

  def mock_llm_client_with_raw_content(raw_content)
    mock = Object.new
    content_capture = raw_content

    mock.define_singleton_method(:ask) do |*args, **kwargs|
      response = Object.new
      response.define_singleton_method(:content) { content_capture }
      response
    end

    mock
  end

  def mock_llm_client_that_raises(error)
    mock = Object.new
    error_capture = error

    mock.define_singleton_method(:ask) do |*args, **kwargs|
      raise error_capture
    end

    mock
  end

  # Stub ImageProcessingService to return a mock processed image
  # Uses Minitest's stub method to replace the service for the duration of the block
  def stub_image_processing(&block)
    mock_processor = mock_image_processor
    ImageProcessingService.stub :new, ->(*args) { mock_processor }, &block
  end

  def mock_image_processor
    processor = Object.new
    processed_image = @mock_processed_image

    processor.define_singleton_method(:call) do
      processed_image
    end

    processor
  end
end
