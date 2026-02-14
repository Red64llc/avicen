require "test_helper"

class RubyLlmConfigurationTest < ActiveSupport::TestCase
  test "RubyLLM is defined and loaded" do
    assert defined?(RubyLLM), "RubyLLM should be defined"
  end

  test "RubyLLM configuration exists" do
    config = RubyLLM.config
    assert_not_nil config, "RubyLLM.config should return a configuration object"
  end

  test "configuration has anthropic api key accessor" do
    config = RubyLLM.config
    assert_respond_to config, :anthropic_api_key,
      "Configuration should have anthropic_api_key accessor"
  end

  test "configuration has request timeout set to 120 seconds" do
    config = RubyLLM.config
    assert_respond_to config, :request_timeout
    assert_equal 120, config.request_timeout,
      "Request timeout should be 120 seconds for document extraction"
  end

  test "configuration has max_retries set to 3" do
    config = RubyLLM.config
    assert_respond_to config, :max_retries
    assert_equal 3, config.max_retries,
      "Max retries should be 3 for transient failure handling"
  end

  test "configuration has retry_interval set to 0.5" do
    config = RubyLLM.config
    assert_respond_to config, :retry_interval
    assert_equal 0.5, config.retry_interval,
      "Retry interval should be 0.5 seconds"
  end

  test "configuration has retry_backoff_factor set to 2" do
    config = RubyLLM.config
    assert_respond_to config, :retry_backoff_factor
    assert_equal 2, config.retry_backoff_factor,
      "Retry backoff factor should be 2 for exponential backoff"
  end

  test "configuration loads without errors in test environment" do
    # Verify no errors when accessing configuration
    assert_nothing_raised do
      RubyLLM.config
    end
  end

  test "default model is Claude Sonnet for vision capabilities" do
    config = RubyLLM.config
    assert_respond_to config, :default_model
    assert_equal "claude-sonnet-4-20250514", config.default_model,
      "Default model should be Claude Sonnet 4 for vision support"
  end

  test "anthropic api key is read from credentials" do
    # This test verifies that the configuration attempts to read from credentials
    # The actual key may be nil in test environment without credentials set up
    config = RubyLLM.config
    expected_key = Rails.application.credentials.dig(:anthropic, :api_key)
    if expected_key.nil?
      assert_nil config.anthropic_api_key,
        "Anthropic API key should be nil when credentials are not set"
    else
      assert_equal expected_key, config.anthropic_api_key,
        "Anthropic API key should be read from Rails credentials"
    end
  end
end
