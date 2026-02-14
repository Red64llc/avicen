# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# Task 12.2: Privacy-safe logging for document scanning feature
# Requirements: 9.3, 9.4, 8.6
# Filter extracted medical content and PII from logs
Rails.application.config.filter_parameters += [
  # Medical data from document scanning
  :extracted_data,           # Full extraction result
  :medications,              # Array of medication data
  :test_results,             # Array of lab test results
  :raw_response,             # Raw API response

  # Individual medical field names
  :drug_name,                # Medication names
  :biomarker_name,           # Lab test names
  :dosage,                   # Medication dosages
  :frequency,                # Medication frequency

  # PII and identifying information
  :doctor_name,              # Healthcare provider names
  :lab_name,                 # Laboratory/facility names
  :prescription_date,        # Date information
  :test_date                 # Date information
]
