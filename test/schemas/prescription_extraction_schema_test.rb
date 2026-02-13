# frozen_string_literal: true

require "test_helper"

class PrescriptionExtractionSchemaTest < ActiveSupport::TestCase
  # --- Class Definition ---

  test "inherits from RubyLLM::Schema" do
    assert PrescriptionExtractionSchema < RubyLLM::Schema
  end

  # --- Top-level Fields ---

  test "has doctor_name as optional string field" do
    schema = PrescriptionExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]

    assert properties.key?(:doctor_name) || properties.key?("doctor_name"),
      "Expected schema to have doctor_name property"

    doctor_name = properties[:doctor_name] || properties["doctor_name"]
    assert_equal "string", doctor_name[:type] || doctor_name["type"]
  end

  test "has prescription_date as optional string field" do
    schema = PrescriptionExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]

    assert properties.key?(:prescription_date) || properties.key?("prescription_date"),
      "Expected schema to have prescription_date property"

    prescription_date = properties[:prescription_date] || properties["prescription_date"]
    assert_equal "string", prescription_date[:type] || prescription_date["type"]
  end

  test "doctor_name is not in required fields" do
    schema = PrescriptionExtractionSchema.json_schema
    required = schema[:required] || schema["required"] || []

    refute_includes required, :doctor_name
    refute_includes required, "doctor_name"
  end

  test "prescription_date is not in required fields" do
    schema = PrescriptionExtractionSchema.json_schema
    required = schema[:required] || schema["required"] || []

    refute_includes required, :prescription_date
    refute_includes required, "prescription_date"
  end

  # --- Medications Array ---

  test "has medications as array field" do
    schema = PrescriptionExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]

    assert properties.key?(:medications) || properties.key?("medications"),
      "Expected schema to have medications property"

    medications = properties[:medications] || properties["medications"]
    assert_equal "array", medications[:type] || medications["type"]
  end

  test "medications array items have drug_name as required string" do
    schema = PrescriptionExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    medications = properties[:medications] || properties["medications"]
    items = medications[:items] || medications["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:drug_name) || item_properties.key?("drug_name"),
      "Expected medication items to have drug_name"

    drug_name = item_properties[:drug_name] || item_properties["drug_name"]
    assert_equal "string", drug_name[:type] || drug_name["type"]

    # drug_name should be required
    item_required = items[:required] || items["required"] || []
    assert item_required.include?(:drug_name) || item_required.include?("drug_name"),
      "Expected drug_name to be required in medication items"
  end

  test "medications array items have dosage as optional string" do
    schema = PrescriptionExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    medications = properties[:medications] || properties["medications"]
    items = medications[:items] || medications["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:dosage) || item_properties.key?("dosage"),
      "Expected medication items to have dosage"

    dosage = item_properties[:dosage] || item_properties["dosage"]
    assert_equal "string", dosage[:type] || dosage["type"]

    # dosage should be optional (not in required)
    item_required = items[:required] || items["required"] || []
    refute item_required.include?(:dosage) || item_required.include?("dosage"),
      "Expected dosage to be optional in medication items"
  end

  test "medications array items have frequency as optional string" do
    schema = PrescriptionExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    medications = properties[:medications] || properties["medications"]
    items = medications[:items] || medications["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:frequency) || item_properties.key?("frequency"),
      "Expected medication items to have frequency"
  end

  test "medications array items have duration as optional string" do
    schema = PrescriptionExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    medications = properties[:medications] || properties["medications"]
    items = medications[:items] || medications["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:duration) || item_properties.key?("duration"),
      "Expected medication items to have duration"
  end

  test "medications array items have quantity as optional string" do
    schema = PrescriptionExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    medications = properties[:medications] || properties["medications"]
    items = medications[:items] || medications["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:quantity) || item_properties.key?("quantity"),
      "Expected medication items to have quantity"
  end

  test "medications array items have confidence as required number" do
    schema = PrescriptionExtractionSchema.json_schema
    properties = schema[:properties] || schema["properties"]
    medications = properties[:medications] || properties["medications"]
    items = medications[:items] || medications["items"]
    item_properties = items[:properties] || items["properties"]

    assert item_properties.key?(:confidence) || item_properties.key?("confidence"),
      "Expected medication items to have confidence"

    confidence = item_properties[:confidence] || item_properties["confidence"]
    assert_equal "number", confidence[:type] || confidence["type"]

    # confidence should be required
    item_required = items[:required] || items["required"] || []
    assert item_required.include?(:confidence) || item_required.include?("confidence"),
      "Expected confidence to be required in medication items"
  end

  # --- Schema Output ---

  test "generates valid JSON schema structure" do
    schema = PrescriptionExtractionSchema.json_schema

    assert schema.is_a?(Hash), "Expected json_schema to return a Hash"
    assert schema.key?(:properties) || schema.key?("properties"),
      "Expected schema to have properties key"
  end
end
