# frozen_string_literal: true

# Schema for structured biology/lab report extraction from Claude Vision API.
#
# Defines the expected JSON output format for lab report document analysis.
# Used with RubyLLM's structured output feature to guarantee response format.
#
# Required fields in test result items:
#   - biomarker_name: Name of the test/biomarker
#   - value: Measured value as string
#   - confidence: Extraction confidence score (0.0 to 1.0)
#
# Optional fields:
#   - lab_name: Name of the laboratory
#   - test_date: Date of the test (YYYY-MM-DD format)
#   - unit: Unit of measurement
#   - reference_range: Normal range (e.g., "3.5-5.0")
#
# @example Usage with RubyLLM
#   chat = RubyLLM.chat(model: "claude-sonnet-4-20250514")
#   response = chat.with_schema(BiologyReportExtractionSchema).ask(
#     "Extract test results from this lab report",
#     with: image_path
#   )
#
# @see PrescriptionExtractionSchema for prescription extraction
# @see https://rubyllm.com/chat/#structured-output RubyLLM Structured Output docs
class BiologyReportExtractionSchema < RubyLLM::Schema
  # Laboratory name (optional)
  string :lab_name, required: false, description: "Name of the laboratory"

  # Test date in YYYY-MM-DD format (optional)
  string :test_date, required: false, description: "Date of the test (YYYY-MM-DD format)"

  # Array of extracted test results
  array :test_results, description: "List of test results extracted from the report" do
    object do
      # Biomarker name is required for each test result
      string :biomarker_name, description: "Name of the test/biomarker"

      # Value is required
      string :value, description: "Measured value as string"

      # Optional test result details
      string :unit, required: false, description: "Unit of measurement"
      string :reference_range, required: false, description: "Normal range (e.g., '3.5-5.0')"

      # Confidence score is required
      number :confidence, description: "Extraction confidence score from 0.0 to 1.0"
    end
  end
end
