# frozen_string_literal: true

require "test_helper"

class BiologyReportExtractionSchemaTest < ActiveSupport::TestCase
  # --- Class Definition ---

  test "inherits from RubyLLM::Schema" do
    assert BiologyReportExtractionSchema < RubyLLM::Schema
  end

  # --- Top-level Fields ---

  test "has lab_name as optional string field" do
    schema = BiologyReportExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]

    assert properties.key?(:lab_name) || properties.key?("lab_name"),
      "Expected schema to have lab_name property"

    lab_name = properties[:lab_name] || properties["lab_name"]
    assert_equal "string", lab_name[:type] || lab_name["type"]
  end

  test "has test_date as optional string field" do
    schema = BiologyReportExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]

    assert properties.key?(:test_date) || properties.key?("test_date"),
      "Expected schema to have test_date property"

    test_date = properties[:test_date] || properties["test_date"]
    assert_equal "string", test_date[:type] || test_date["type"]
  end

  test "lab_name is not in required fields" do
    schema = BiologyReportExtractionSchema.json_schema
    required = schema[:required] || schema["required"] || []

    refute_includes required, :lab_name
    refute_includes required, "lab_name"
  end

  test "test_date is not in required fields" do
    schema = BiologyReportExtractionSchema.json_schema
    required = schema[:required] || schema["required"] || []

    refute_includes required, :test_date
    refute_includes required, "test_date"
  end

  # --- Test Results Array ---

  test "has test_results as array field" do
    schema = BiologyReportExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]

    assert properties.key?(:test_results) || properties.key?("test_results"),
      "Expected schema to have test_results property"

    test_results = properties[:test_results] || properties["test_results"]
    assert_equal "array", test_results[:type] || test_results["type"]
  end

  test "test_results array items have biomarker_name as required string" do
    schema = BiologyReportExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    test_results = properties[:test_results] || properties["test_results"]
    items = test_results[:items] || test_results["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:biomarker_name) || item_properties.key?("biomarker_name"),
      "Expected test result items to have biomarker_name"

    biomarker_name = item_properties[:biomarker_name] || item_properties["biomarker_name"]
    assert_equal "string", biomarker_name[:type] || biomarker_name["type"]

    # biomarker_name should be required
    item_required = items[:required] || items["required"] || []
    assert item_required.include?(:biomarker_name) || item_required.include?("biomarker_name"),
      "Expected biomarker_name to be required in test result items"
  end

  test "test_results array items have value as required string" do
    schema = BiologyReportExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    test_results = properties[:test_results] || properties["test_results"]
    items = test_results[:items] || test_results["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:value) || item_properties.key?("value"),
      "Expected test result items to have value"

    value = item_properties[:value] || item_properties["value"]
    assert_equal "string", value[:type] || value["type"]

    # value should be required
    item_required = items[:required] || items["required"] || []
    assert item_required.include?(:value) || item_required.include?("value"),
      "Expected value to be required in test result items"
  end

  test "test_results array items have unit as optional string" do
    schema = BiologyReportExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    test_results = properties[:test_results] || properties["test_results"]
    items = test_results[:items] || test_results["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:unit) || item_properties.key?("unit"),
      "Expected test result items to have unit"

    unit = item_properties[:unit] || item_properties["unit"]
    assert_equal "string", unit[:type] || unit["type"]

    # unit should be optional (not in required)
    item_required = items[:required] || items["required"] || []
    refute item_required.include?(:unit) || item_required.include?("unit"),
      "Expected unit to be optional in test result items"
  end

  test "test_results array items have reference_range as optional string" do
    schema = BiologyReportExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    test_results = properties[:test_results] || properties["test_results"]
    items = test_results[:items] || test_results["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:reference_range) || item_properties.key?("reference_range"),
      "Expected test result items to have reference_range"

    reference_range = item_properties[:reference_range] || item_properties["reference_range"]
    assert_equal "string", reference_range[:type] || reference_range["type"]

    # reference_range should be optional (not in required)
    item_required = items[:required] || items["required"] || []
    refute item_required.include?(:reference_range) || item_required.include?("reference_range"),
      "Expected reference_range to be optional in test result items"
  end

  test "test_results array items have confidence as required number" do
    schema = BiologyReportExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    test_results = properties[:test_results] || properties["test_results"]
    items = test_results[:items] || test_results["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:confidence) || item_properties.key?("confidence"),
      "Expected test result items to have confidence"

    confidence = item_properties[:confidence] || item_properties["confidence"]
    assert_equal "number", confidence[:type] || confidence["type"]

    # confidence should be required
    item_required = items[:required] || items["required"] || []
    assert item_required.include?(:confidence) || item_required.include?("confidence"),
      "Expected confidence to be required in test result items"
  end

  # --- Schema Output ---

  test "generates valid JSON schema structure" do
    schema = BiologyReportExtractionSchema.json_schema

    assert schema.is_a?(Hash), "Expected json_schema to return a Hash"
    assert schema.key?(:properties) || schema.key?("properties"),
      "Expected schema to have properties key"
  end
end
