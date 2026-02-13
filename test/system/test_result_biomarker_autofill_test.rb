require "application_system_test_case"

class TestResultBiomarkerAutofillTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as_system(@user)
    @biology_report = biology_reports(:one)
    @glucose = biomarkers(:glucose)
    @hemoglobin = biomarkers(:hemoglobin)
  end

  test "form auto-fills unit and reference ranges when biomarker is selected" do
    visit new_biology_report_test_result_path(@biology_report)

    # Initially, unit and reference range fields should be empty
    assert_equal "", find_field("Unit of Measurement").value
    assert_equal "", find_field("Minimum Value").value
    assert_equal "", find_field("Maximum Value").value

    # Select a biomarker from dropdown
    select @glucose.name, from: "Biomarker"

    # Wait for Stimulus controller to populate fields
    # The fields should be auto-filled with biomarker's default values
    assert_equal @glucose.unit, find_field("Unit of Measurement").value
    assert_equal @glucose.ref_min.to_s, find_field("Minimum Value").value
    assert_equal @glucose.ref_max.to_s, find_field("Maximum Value").value
  end

  test "form allows user to override auto-filled reference range values" do
    visit new_biology_report_test_result_path(@biology_report)

    # Select a biomarker
    select @glucose.name, from: "Biomarker"

    # Wait for auto-fill
    assert_equal @glucose.ref_min.to_s, find_field("Minimum Value").value
    assert_equal @glucose.ref_max.to_s, find_field("Maximum Value").value

    # Override the auto-filled values
    fill_in "Minimum Value", with: "65.0"
    fill_in "Maximum Value", with: "110.0"

    # Verify overridden values are preserved
    assert_equal "65.0", find_field("Minimum Value").value
    assert_equal "110.0", find_field("Maximum Value").value
  end

  test "form updates auto-filled values when biomarker selection changes" do
    visit new_biology_report_test_result_path(@biology_report)

    # Select first biomarker
    select @glucose.name, from: "Biomarker"
    assert_equal @glucose.unit, find_field("Unit of Measurement").value

    # Change to different biomarker
    select @hemoglobin.name, from: "Biomarker"

    # Values should update to new biomarker's defaults
    assert_equal @hemoglobin.unit, find_field("Unit of Measurement").value
    assert_equal @hemoglobin.ref_min.to_s, find_field("Minimum Value").value
    assert_equal @hemoglobin.ref_max.to_s, find_field("Maximum Value").value
  end

  test "form auto-fills when biomarker_id is provided via query parameter" do
    # Visit new form with biomarker_id in URL (existing behavior)
    visit new_biology_report_test_result_path(@biology_report, biomarker_id: @glucose.id)

    # Fields should be pre-filled from server-side logic
    assert_equal @glucose.unit, find_field("Unit of Measurement").value
    assert_equal @glucose.ref_min.to_s, find_field("Minimum Value").value
    assert_equal @glucose.ref_max.to_s, find_field("Maximum Value").value
  end

  test "form preserves manual entries for value when biomarker changes" do
    visit new_biology_report_test_result_path(@biology_report)

    # Enter a test value
    fill_in "Test Value", with: "95.0"

    # Select biomarker (should not clear the test value)
    select @glucose.name, from: "Biomarker"

    # Test value should still be present
    assert_equal "95.0", find_field("Test Value").value
  end
end
