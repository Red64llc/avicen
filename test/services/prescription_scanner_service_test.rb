# frozen_string_literal: true

require "test_helper"

class PrescriptionScannerServiceTest < ActiveSupport::TestCase
  setup do
    @aspirin = drugs(:aspirin)
    @ibuprofen = drugs(:ibuprofen)
    @user = users(:one)

    # Create a mock blob for testing
    @mock_blob = create_mock_blob

    # Stub ImageProcessingService to avoid actual image processing in tests
    @processed_image_path = "/tmp/test_processed_image.jpg"
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

  # --- Error Hierarchy Tests (Task 5.1) ---

  test "defines Error base class" do
    assert_kind_of Class, PrescriptionScannerService::Error
    assert PrescriptionScannerService::Error < StandardError
  end

  test "defines ConfigurationError" do
    assert_kind_of Class, PrescriptionScannerService::ConfigurationError
    assert PrescriptionScannerService::ConfigurationError < PrescriptionScannerService::Error
  end

  test "defines AuthenticationError" do
    assert_kind_of Class, PrescriptionScannerService::AuthenticationError
    assert PrescriptionScannerService::AuthenticationError < PrescriptionScannerService::Error
  end

  test "defines RateLimitError" do
    assert_kind_of Class, PrescriptionScannerService::RateLimitError
    assert PrescriptionScannerService::RateLimitError < PrescriptionScannerService::Error
  end

  test "defines ExtractionError" do
    assert_kind_of Class, PrescriptionScannerService::ExtractionError
    assert PrescriptionScannerService::ExtractionError < PrescriptionScannerService::Error
  end

  # --- ExtractionResult Value Object Tests (Task 5.1) ---

  test "ExtractionResult.success creates successful result" do
    medications = [ build_extracted_medication(drug_name: "Aspirin") ]
    result = PrescriptionScannerService::ExtractionResult.success(
      medications: medications,
      doctor_name: "Dr. Smith",
      prescription_date: "2026-01-15",
      raw_response: { test: "data" }
    )

    assert result.success?
    assert_not result.error?
    assert_equal medications, result.medications
    assert_equal "Dr. Smith", result.doctor_name
    assert_equal "2026-01-15", result.prescription_date
    assert_equal({ test: "data" }, result.raw_response)
  end

  test "ExtractionResult.error creates error result" do
    result = PrescriptionScannerService::ExtractionResult.error(
      type: :api_error,
      message: "API returned 500"
    )

    assert result.error?
    assert_not result.success?
    assert_equal :api_error, result.error_type
    assert_equal "API returned 500", result.error_message
  end

  test "ExtractionResult is immutable" do
    result = PrescriptionScannerService::ExtractionResult.success(
      medications: [],
      doctor_name: "Dr. Smith",
      prescription_date: "2026-01-15",
      raw_response: {}
    )

    assert result.frozen?
  end

  # --- ExtractedMedication Data Class Tests (Task 5.1) ---

  test "ExtractedMedication stores all medication fields" do
    med = PrescriptionScannerService::ExtractedMedication.new(
      drug_name: "Aspirin 500mg",
      dosage: "500mg",
      frequency: "twice daily",
      duration: "7 days",
      quantity: "14",
      confidence: 0.95,
      matched_drug: @aspirin,
      requires_verification: false,
      active_ingredients: [ "Aspirin" ],
      rxcui: "1191"
    )

    assert_equal "Aspirin 500mg", med.drug_name
    assert_equal "500mg", med.dosage
    assert_equal "twice daily", med.frequency
    assert_equal "7 days", med.duration
    assert_equal "14", med.quantity
    assert_equal 0.95, med.confidence
    assert_equal @aspirin, med.matched_drug
    assert_equal false, med.requires_verification
    assert_equal [ "Aspirin" ], med.active_ingredients
    assert_equal "1191", med.rxcui
  end

  test "ExtractedMedication is immutable" do
    med = build_extracted_medication(drug_name: "Aspirin")
    assert med.frozen?
  end

  # --- Constructor Tests (Task 5.1) ---

  test "accepts image blob in constructor" do
    service = PrescriptionScannerService.new(image_blob: @mock_blob)
    assert_not_nil service
  end

  test "accepts optional llm_client for testing" do
    mock_client = Object.new
    service = PrescriptionScannerService.new(image_blob: @mock_blob, llm_client: mock_client)
    assert_not_nil service
  end

  # --- Successful Extraction Tests (Task 5.2) ---

  test "extracts single medication from prescription image" do
    mock_response = build_mock_llm_response(
      doctor_name: "Dr. Smith",
      prescription_date: "2026-01-15",
      medications: [
        { drug_name: "Aspirin 500mg", dosage: "500mg", frequency: "twice daily", confidence: 0.95 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_equal 1, result.medications.length
      assert_equal "Aspirin 500mg", result.medications.first.drug_name
      assert_equal "500mg", result.medications.first.dosage
      assert_equal "Dr. Smith", result.doctor_name
    end
  end

  test "extracts multiple medications from single prescription" do
    mock_response = build_mock_llm_response(
      doctor_name: "Dr. Johnson",
      prescription_date: "2026-02-01",
      medications: [
        { drug_name: "Aspirin 500mg", dosage: "500mg", frequency: "once daily", confidence: 0.9 },
        { drug_name: "Ibuprofen 200mg", dosage: "200mg", frequency: "twice daily", confidence: 0.85 },
        { drug_name: "Metformin 500mg", dosage: "500mg", frequency: "with meals", confidence: 0.8 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_equal 3, result.medications.length
      assert_equal "Aspirin 500mg", result.medications[0].drug_name
      assert_equal "Ibuprofen 200mg", result.medications[1].drug_name
      assert_equal "Metformin 500mg", result.medications[2].drug_name
    end
  end

  test "includes raw response in result for audit" do
    mock_response = build_mock_llm_response(
      medications: [ { drug_name: "Aspirin", confidence: 0.9 } ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_not_nil result.raw_response
    end
  end

  # --- JSON Parsing Tests (Task 5.2) ---

  test "handles JSON response wrapped in markdown code fence" do
    json_content = {
      doctor_name: "Dr. Smith",
      prescription_date: "2026-01-15",
      medications: [
        { drug_name: "Aspirin", confidence: 0.9 }
      ]
    }.to_json

    markdown_wrapped = "```json\n#{json_content}\n```"

    mock_client = mock_llm_client_with_raw_content(markdown_wrapped)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal "Dr. Smith", result.doctor_name
      assert_equal 1, result.medications.length
    end
  end

  test "handles JSON response without markdown fence" do
    json_content = {
      doctor_name: "Dr. Jones",
      medications: [ { drug_name: "Ibuprofen", confidence: 0.85 } ]
    }.to_json

    mock_client = mock_llm_client_with_raw_content(json_content)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal "Dr. Jones", result.doctor_name
    end
  end

  test "handles markdown fence with language specifier" do
    json_content = {
      medications: [ { drug_name: "Aspirin", confidence: 0.9 } ]
    }.to_json

    markdown_wrapped = "```json\n#{json_content}\n```"

    mock_client = mock_llm_client_with_raw_content(markdown_wrapped)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
    end
  end

  test "handles markdown fence without language specifier" do
    json_content = {
      medications: [ { drug_name: "Aspirin", confidence: 0.9 } ]
    }.to_json

    markdown_wrapped = "```\n#{json_content}\n```"

    mock_client = mock_llm_client_with_raw_content(markdown_wrapped)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal 1, result.medications.length
    end
  end

  test "handles JSON with leading and trailing whitespace" do
    json_content = {
      medications: [ { drug_name: "Aspirin", confidence: 0.9 } ]
    }.to_json

    whitespace_padded = "   \n\n#{json_content}\n\n   "

    mock_client = mock_llm_client_with_raw_content(whitespace_padded)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
    end
  end

  test "handles markdown fence with javascript language specifier" do
    json_content = {
      medications: [ { drug_name: "Aspirin", confidence: 0.9 } ]
    }.to_json

    # Some LLMs might use ```javascript instead of ```json
    markdown_wrapped = "```javascript\n#{json_content}\n```"

    mock_client = mock_llm_client_with_raw_content(markdown_wrapped)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
    end
  end

  # --- Drug Matching Tests (Task 5.3) ---

  test "matches extracted drug names against local Drug database" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Aspirin", dosage: "500mg", confidence: 0.95 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert_equal @aspirin, medication.matched_drug
      assert_equal "1191", medication.rxcui
      assert_includes medication.active_ingredients, "Aspirin"
    end
  end

  test "uses fuzzy matching for drug name variations" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Ibuprofen 200mg Tablet", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert_equal @ibuprofen, medication.matched_drug
    end
  end

  test "sets matched_drug to nil when no match found" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Unknown Mystery Drug XYZ", confidence: 0.8 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert_nil medication.matched_drug
      assert_nil medication.rxcui
      assert_nil medication.active_ingredients
    end
  end

  test "matches drug with case-insensitive exact match" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "ASPIRIN", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert_equal @aspirin, medication.matched_drug
    end
  end

  test "matches drug when extracted name contains database drug name" do
    # The fixture has "Ibuprofen 200mg Oral Tablet"
    # Test that "Advil Ibuprofen 200mg" matches by finding "Ibuprofen" word
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Advil Ibuprofen 400mg Extended Release", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert_equal @ibuprofen, medication.matched_drug
    end
  end

  test "handles blank drug name gracefully" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "", confidence: 0.5 }
      ]
    )

    mock_client = mock_llm_client_with_raw_content(mock_response.to_json)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      # Should return extraction error because drug_name is required and blank
      assert result.error?
      assert_equal :extraction, result.error_type
    end
  end

  test "matches multiple medications with different match outcomes" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Aspirin", confidence: 0.95 },
        { drug_name: "Ibuprofen 200mg", confidence: 0.88 },
        { drug_name: "Nonexistent Drug ABC", confidence: 0.7 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_equal 3, result.medications.length

      # First medication should match Aspirin
      assert_equal @aspirin, result.medications[0].matched_drug
      assert_equal "1191", result.medications[0].rxcui

      # Second medication should match Ibuprofen
      assert_equal @ibuprofen, result.medications[1].matched_drug
      assert_equal "310965", result.medications[1].rxcui

      # Third medication should have no match
      assert_nil result.medications[2].matched_drug
      assert_nil result.medications[2].rxcui
    end
  end

  test "populates active_ingredients from matched drug" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Aspirin", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert_not_nil medication.active_ingredients
      assert_kind_of Array, medication.active_ingredients
      assert_includes medication.active_ingredients, "Aspirin"
    end
  end

  # --- Confidence Scoring Tests (Task 5.3) ---

  test "flags medication with low confidence as requiring verification" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Aspirin", confidence: 0.4 } # Below 0.5 threshold
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert medication.requires_verification
    end
  end

  test "does not flag medication with high confidence" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Aspirin", confidence: 0.9 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert_not medication.requires_verification
    end
  end

  test "uses confidence threshold of 0.5 for verification flag" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Aspirin", confidence: 0.5 }, # Exactly at threshold
        { drug_name: "Ibuprofen", confidence: 0.49 } # Just below threshold
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_not result.medications[0].requires_verification # 0.5 is OK
      assert result.medications[1].requires_verification # 0.49 needs verification
    end
  end

  # --- Error Handling Tests (Task 5.4) ---

  test "returns error result on rate limit error" do
    mock_client = mock_llm_client_that_raises(RubyLLM::RateLimitError.new(nil))

    stub_image_processing do
      service = PrescriptionScannerService.new(
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
      service = PrescriptionScannerService.new(
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
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :authentication, result.error_type
    end
  end

  test "returns error result on authentication error with message" do
    mock_client = mock_llm_client_that_raises(
      RubyLLM::UnauthorizedError.new(OpenStruct.new(body: "Invalid API key"))
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :authentication, result.error_type
      assert_not_nil result.error_message
    end
  end

  test "returns error result on API error" do
    mock_client = mock_llm_client_that_raises(RubyLLM::Error.new(nil))

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :api_error, result.error_type
    end
  end

  test "returns error result on network error wrapped as API error" do
    # Network errors like connection refused, timeouts etc. are wrapped by ruby_llm
    mock_client = mock_llm_client_that_raises(
      RubyLLM::Error.new(nil)
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :api_error, result.error_type
    end
  end

  test "returns error result on timeout wrapped as API error" do
    mock_client = mock_llm_client_that_raises(
      RubyLLM::Error.new(nil)
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
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
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
    end
  end

  test "returns error result when response missing required medications field" do
    mock_client = mock_llm_client_with_raw_content('{"doctor_name": "Dr. Smith"}')

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
    end
  end

  # --- Schema Validation Tests (Task 5.2) ---

  test "returns error when medication missing required drug_name field" do
    mock_client = mock_llm_client_with_raw_content(
      '{"medications": [{"dosage": "500mg", "confidence": 0.9}]}'
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
      assert_match(/drug_name/i, result.error_message)
    end
  end

  test "returns error when medication missing required confidence field" do
    mock_client = mock_llm_client_with_raw_content(
      '{"medications": [{"drug_name": "Aspirin", "dosage": "500mg"}]}'
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
      assert_match(/confidence/i, result.error_message)
    end
  end

  test "handles medication with all optional fields missing except required ones" do
    mock_client = mock_llm_client_with_raw_content(
      '{"medications": [{"drug_name": "Aspirin", "confidence": 0.9}]}'
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal 1, result.medications.length
      medication = result.medications.first
      assert_equal "Aspirin", medication.drug_name
      assert_equal 0.9, medication.confidence
      assert_nil medication.dosage
      assert_nil medication.frequency
      assert_nil medication.duration
      assert_nil medication.quantity
    end
  end

  test "validates medications array is not empty when extraction returns no medications" do
    mock_client = mock_llm_client_with_raw_content(
      '{"doctor_name": "Dr. Smith", "medications": []}'
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      # Empty medications array should still succeed - it's valid JSON
      # The caller can decide how to handle empty extractions
      assert result.success?
      assert_equal 0, result.medications.length
    end
  end

  test "returns error when response is not a JSON object" do
    mock_client = mock_llm_client_with_raw_content('["not", "an", "object"]')

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
      assert_match(/not a JSON object/i, result.error_message)
    end
  end

  test "returns error when medications is not an array" do
    mock_client = mock_llm_client_with_raw_content(
      '{"medications": "not an array"}'
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
    end
  end

  test "returns error when medication entry is not an object" do
    mock_client = mock_llm_client_with_raw_content(
      '{"medications": ["just a string"]}'
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.error?
      assert_equal :extraction, result.error_type
      assert_match(/not an object/i, result.error_message)
    end
  end

  test "handles all optional prescription fields" do
    mock_response = build_mock_llm_response(
      doctor_name: "Dr. Sarah Johnson",
      prescription_date: "2026-02-13",
      medications: [
        {
          drug_name: "Aspirin",
          dosage: "81mg",
          frequency: "once daily",
          duration: "30 days",
          quantity: "30",
          confidence: 0.95
        }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      assert_equal "Dr. Sarah Johnson", result.doctor_name
      assert_equal "2026-02-13", result.prescription_date

      medication = result.medications.first
      assert_equal "Aspirin", medication.drug_name
      assert_equal "81mg", medication.dosage
      assert_equal "once daily", medication.frequency
      assert_equal "30 days", medication.duration
      assert_equal "30", medication.quantity
      assert_equal 0.95, medication.confidence
    end
  end

  test "handles null values in optional fields" do
    json_with_nulls = {
      doctor_name: nil,
      prescription_date: nil,
      medications: [
        {
          drug_name: "Aspirin",
          dosage: nil,
          frequency: nil,
          duration: nil,
          quantity: nil,
          confidence: 0.8
        }
      ]
    }.to_json

    mock_client = mock_llm_client_with_raw_content(json_with_nulls)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_nil result.doctor_name
      assert_nil result.prescription_date
      assert_nil result.medications.first.dosage
    end
  end

  test "preserves confidence value of zero" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Possibly Aspirin?", confidence: 0.0 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert_equal 0.0, medication.confidence
      assert medication.requires_verification
    end
  end

  test "handles confidence value of one" do
    mock_response = build_mock_llm_response(
      medications: [
        { drug_name: "Aspirin", confidence: 1.0 }
      ]
    )

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_llm_client(mock_response)
      )

      result = service.call

      assert result.success?
      medication = result.medications.first
      assert_equal 1.0, medication.confidence
      assert_not medication.requires_verification
    end
  end

  # --- Sample Prescription JSON Tests (Task 5.4) ---

  test "extracts data from realistic prescription JSON response" do
    # Simulates a realistic response from Claude Vision API
    realistic_response = {
      doctor_name: "Dr. Michael Chen, MD",
      prescription_date: "2026-02-10",
      medications: [
        {
          drug_name: "Aspirin 81mg Enteric Coated Tablet",
          dosage: "81mg",
          frequency: "once daily in the morning",
          duration: "ongoing",
          quantity: "90",
          confidence: 0.92
        },
        {
          drug_name: "Ibuprofen 200mg",
          dosage: "200mg",
          frequency: "every 6 hours as needed for pain",
          duration: "7 days",
          quantity: "28",
          confidence: 0.88
        }
      ]
    }.to_json

    mock_client = mock_llm_client_with_raw_content(realistic_response)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?
      assert_equal "Dr. Michael Chen, MD", result.doctor_name
      assert_equal "2026-02-10", result.prescription_date
      assert_equal 2, result.medications.length

      # First medication
      aspirin = result.medications[0]
      assert_equal "Aspirin 81mg Enteric Coated Tablet", aspirin.drug_name
      assert_equal "81mg", aspirin.dosage
      assert_equal "once daily in the morning", aspirin.frequency
      assert_equal @aspirin, aspirin.matched_drug
      assert_not aspirin.requires_verification

      # Second medication
      ibuprofen = result.medications[1]
      assert_equal "Ibuprofen 200mg", ibuprofen.drug_name
      assert_equal "every 6 hours as needed for pain", ibuprofen.frequency
      assert_equal @ibuprofen, ibuprofen.matched_drug
    end
  end

  test "handles response with mixed confidence levels" do
    response_with_mixed_confidence = {
      doctor_name: "Dr. Smith",
      medications: [
        { drug_name: "Aspirin", confidence: 0.95 },          # High confidence
        { drug_name: "Metformin 500mg", confidence: 0.65 },  # Medium confidence
        { drug_name: "Unclear Med", confidence: 0.3 }        # Low confidence
      ]
    }.to_json

    mock_client = mock_llm_client_with_raw_content(response_with_mixed_confidence)

    stub_image_processing do
      service = PrescriptionScannerService.new(
        image_blob: @mock_blob,
        llm_client: mock_client
      )

      result = service.call

      assert result.success?

      # High confidence - no verification needed
      assert_not result.medications[0].requires_verification

      # Medium confidence - no verification needed (above 0.5)
      assert_not result.medications[1].requires_verification

      # Low confidence - verification required
      assert result.medications[2].requires_verification
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

  def build_extracted_medication(attrs = {})
    defaults = {
      drug_name: "Test Drug",
      dosage: nil,
      frequency: nil,
      duration: nil,
      quantity: nil,
      confidence: 0.9,
      matched_drug: nil,
      requires_verification: false,
      active_ingredients: nil,
      rxcui: nil
    }
    PrescriptionScannerService::ExtractedMedication.new(**defaults.merge(attrs))
  end

  def build_mock_llm_response(attrs = {})
    {
      doctor_name: attrs[:doctor_name],
      prescription_date: attrs[:prescription_date],
      medications: attrs[:medications] || []
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
