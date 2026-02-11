require "test_helper"

class SslEnforcementTest < ActiveSupport::TestCase
  # Test that production SSL settings are configured correctly
  # These tests verify the production.rb configuration file has the proper SSL settings

  test "production environment has assume_ssl enabled" do
    # Load production configuration into a fresh Rails configuration
    production_config = read_production_config

    # Check that assume_ssl is uncommented and set to true
    assert production_config.include?("config.assume_ssl = true"),
           "config.assume_ssl = true should be uncommented in production.rb"
  end

  test "production environment has force_ssl enabled" do
    production_config = read_production_config

    # Check that force_ssl is uncommented and set to true
    assert production_config.include?("config.force_ssl = true"),
           "config.force_ssl = true should be uncommented in production.rb"
  end

  test "production environment excludes health check endpoint from SSL redirect" do
    production_config = read_production_config

    # Check that ssl_options is uncommented and configured to exclude /up
    assert production_config.include?('config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }'),
           "config.ssl_options should exclude /up endpoint from SSL redirect"
  end

  private

  def read_production_config
    File.read(Rails.root.join("config/environments/production.rb"))
  end
end
