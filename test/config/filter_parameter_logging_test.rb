# frozen_string_literal: true

require "test_helper"

# Task 12.2: Privacy-safe logging tests
# Requirements: 9.3, 9.4, 8.6
class FilterParameterLoggingTest < ActiveSupport::TestCase
  setup do
    @filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
  end

  # --- Task 12.2: Privacy-Safe Logging Tests ---
  # Requirements: 9.3, 9.4

  test "extracted_data is filtered from logs" do
    # Requirement 9.3: Filter extracted medical content from logs
    params = {
      scan: {
        document_type: "prescription",
        extracted_data: {
          doctor_name: "Dr. Smith",
          medications: [
            { drug_name: "Metformin", dosage: "500mg", frequency: "twice daily" }
          ]
        }
      }
    }

    filtered = @filter.filter(params)

    # The entire extracted_data hash should be filtered
    assert_equal "[FILTERED]", filtered[:scan][:extracted_data]
  end

  test "medications array is filtered from logs" do
    # Requirement 9.3: Filter medical content from logs
    params = {
      scan: {
        medications: [
          { drug_name: "Aspirin", dosage: "100mg" },
          { drug_name: "Lisinopril", dosage: "10mg" }
        ]
      }
    }

    filtered = @filter.filter(params)

    # Medications should be filtered
    assert_equal "[FILTERED]", filtered[:scan][:medications]
  end

  test "test_results array is filtered from logs" do
    # Requirement 9.3: Filter medical content from logs
    params = {
      scan: {
        test_results: [
          { biomarker_name: "Glucose", value: "95", unit: "mg/dL" },
          { biomarker_name: "HbA1c", value: "6.5", unit: "%" }
        ]
      }
    }

    filtered = @filter.filter(params)

    # Test results should be filtered
    assert_equal "[FILTERED]", filtered[:scan][:test_results]
  end

  test "drug_name is filtered from logs" do
    # Requirement 9.3: Individual medical field names are filtered
    params = {
      medication: {
        drug_name: "Sensitive Drug Name",
        dosage: "50mg"
      }
    }

    filtered = @filter.filter(params)

    assert_equal "[FILTERED]", filtered[:medication][:drug_name]
  end

  test "biomarker_name is filtered from logs" do
    # Requirement 9.3: Individual medical field names are filtered
    params = {
      test_result: {
        biomarker_name: "Cholesterol",
        value: "200"
      }
    }

    filtered = @filter.filter(params)

    assert_equal "[FILTERED]", filtered[:test_result][:biomarker_name]
  end

  test "doctor_name is filtered from logs" do
    # Requirement 9.4: PII is filtered
    params = {
      prescription: {
        doctor_name: "Dr. Sensitive Name"
      }
    }

    filtered = @filter.filter(params)

    assert_equal "[FILTERED]", filtered[:prescription][:doctor_name]
  end

  test "lab_name is filtered from logs" do
    # Requirement 9.4: Medical facility names are filtered
    params = {
      biology_report: {
        lab_name: "Sensitive Lab Name"
      }
    }

    filtered = @filter.filter(params)

    assert_equal "[FILTERED]", filtered[:biology_report][:lab_name]
  end

  test "non-sensitive parameters are not filtered" do
    # Verify that non-sensitive data is not filtered
    params = {
      scan: {
        document_type: "prescription",
        blob_id: "12345"
      }
    }

    filtered = @filter.filter(params)

    assert_equal "prescription", filtered[:scan][:document_type]
    assert_equal "12345", filtered[:scan][:blob_id]
  end

  test "existing sensitive parameters remain filtered" do
    # Verify existing filters are still in place
    params = {
      user: {
        email: "test@example.com",
        password: "secret123",
        token: "abc123"
      }
    }

    filtered = @filter.filter(params)

    assert_equal "[FILTERED]", filtered[:user][:email]
    assert_equal "[FILTERED]", filtered[:user][:password]
    assert_equal "[FILTERED]", filtered[:user][:token]
  end

  test "raw_response from extraction is filtered" do
    # Requirement 8.6: Log extraction failures without sensitive details
    params = {
      extraction: {
        raw_response: { medical_data: "sensitive content" }
      }
    }

    filtered = @filter.filter(params)

    assert_equal "[FILTERED]", filtered[:extraction][:raw_response]
  end

  test "confidence values are not filtered" do
    # Confidence scores are not sensitive
    params = {
      extraction_result: {
        confidence: 0.95,
        status: "success"
      }
    }

    filtered = @filter.filter(params)

    assert_equal 0.95, filtered[:extraction_result][:confidence]
    assert_equal "success", filtered[:extraction_result][:status]
  end
end
