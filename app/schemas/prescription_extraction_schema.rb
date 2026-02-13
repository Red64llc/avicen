# frozen_string_literal: true

# Schema for structured prescription extraction from Claude Vision API.
#
# Defines the expected JSON output format for prescription document analysis.
# Used with RubyLLM's structured output feature to guarantee response format.
#
# Required fields in medication items:
#   - drug_name: Name of the medication
#   - confidence: Extraction confidence score (0.0 to 1.0)
#
# Optional fields:
#   - doctor_name: Prescribing doctor's name
#   - prescription_date: Date on the prescription (YYYY-MM-DD format)
#   - dosage: Dosage amount and unit (e.g., "500mg")
#   - frequency: How often to take (e.g., "twice daily")
#   - duration: Treatment duration (e.g., "7 days")
#   - quantity: Number of pills/doses prescribed
#
# @example Usage with RubyLLM
#   chat = RubyLLM.chat(model: "claude-sonnet-4-20250514")
#   response = chat.with_schema(PrescriptionExtractionSchema).ask(
#     "Extract prescription data from this image",
#     with: image_path
#   )
#
# @see BiologyReportExtractionSchema for lab report extraction
# @see https://rubyllm.com/chat/#structured-output RubyLLM Structured Output docs
class PrescriptionExtractionSchema < RubyLLM::Schema
  # Prescribing doctor's name (optional)
  string :doctor_name, required: false, description: "Prescribing doctor's name"

  # Prescription date in YYYY-MM-DD format (optional)
  string :prescription_date, required: false, description: "Date on prescription (YYYY-MM-DD format)"

  # Array of extracted medications
  array :medications, description: "List of medications extracted from the prescription" do
    object do
      # Drug name is required for each medication
      string :drug_name, description: "Name of the medication"

      # Optional medication details
      string :dosage, required: false, description: "Dosage amount and unit (e.g., '500mg')"
      string :frequency, required: false, description: "How often to take (e.g., 'twice daily')"
      string :duration, required: false, description: "Treatment duration (e.g., '7 days')"
      string :quantity, required: false, description: "Number of pills/doses prescribed"

      # Confidence score is required
      number :confidence, description: "Extraction confidence score from 0.0 to 1.0"
    end
  end
end
