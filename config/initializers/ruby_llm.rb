# frozen_string_literal: true

# RubyLLM Configuration
#
# Configure the ruby_llm gem for Claude Vision API integration.
# API keys are stored in Rails encrypted credentials.
#
# To add the Anthropic API key, run:
#   bin/rails credentials:edit
#
# And add:
#   anthropic:
#     api_key: sk-ant-...
#
# Reference: https://rubyllm.com/configuration/

RubyLLM.configure do |config|
  # API Keys from Rails credentials
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic, :api_key)

  # Default model for vision capabilities (Claude Sonnet supports vision)
  # Model ID follows pattern: claude-{variant}-{version}-{date}
  config.default_model = "claude-sonnet-4-20250514"

  # Request timeout in seconds
  # Set to 120s to accommodate document extraction which may take longer
  config.request_timeout = 120

  # Retry configuration for transient failures (rate limits, network issues)
  # These settings provide exponential backoff: 0.5s, 1s, 2s
  config.max_retries = 3
  config.retry_interval = 0.5
  config.retry_backoff_factor = 2

  # Optional: Use Rails logger for debugging in development
  config.logger = Rails.logger if Rails.env.development?
end
