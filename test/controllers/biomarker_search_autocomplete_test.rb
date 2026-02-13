require "test_helper"

# Tests that the biomarker search endpoint returns HTML fragments compatible with
# the stimulus-autocomplete library and the biomarker-search Stimulus controller.
#
# The biomarker-search controller extends stimulus-autocomplete, so the server must
# return <li> elements with:
#   - data-autocomplete-value set to the Biomarker ID (for hidden input)
#   - role="option" for accessibility
#   - visible text content showing the biomarker name (for text input display)
#   - data attributes for biomarker details (name, code, unit, ref_min, ref_max)
#     for auto-filling form fields upon selection
#
# Requirements: 1.2, 1.3
class BiomarkerSearchAutocompleteTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)

    @glucose = Biomarker.create!(
      name: "Glucose",
      code: "2345-7",
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )
  end

  test "search results include role=option for stimulus-autocomplete compatibility" do
    get biomarkers_search_path(q: "Glucose")

    assert_response :success
    assert_select "li[role='option']", minimum: 1
  end

  test "search results include data-autocomplete-value with biomarker ID for hidden input capture" do
    get biomarkers_search_path(q: "Glucose")

    assert_response :success
    assert_select "li[data-autocomplete-value='#{@glucose.id}']", count: 1
    assert_select "li[data-autocomplete-value='#{@glucose.id}']", text: /Glucose/
  end

  test "search results display biomarker name as text content for text input display" do
    get biomarkers_search_path(q: "Glucose")

    assert_response :success
    assert_select "li", text: /Glucose \(2345-7\)/
  end

  test "each search result li has data attributes for auto-filling form fields" do
    get biomarkers_search_path(q: "Glucose")

    assert_response :success
    assert_select "li[data-biomarker-name='Glucose']"
    assert_select "li[data-biomarker-code='2345-7']"
    assert_select "li[data-biomarker-unit='mg/dL']"
    assert_select "li[data-biomarker-ref-min='70.0']"
    assert_select "li[data-biomarker-ref-max='100.0']"
  end

  test "each search result li has both data-autocomplete-value and role=option" do
    hemoglobin = Biomarker.create!(
      name: "Hemoglobin",
      code: "718-7",
      unit: "g/dL",
      ref_min: 13.5,
      ref_max: 17.5
    )

    get biomarkers_search_path(q: "o") # matches "Glucose", "Hemoglobin"

    assert_response :success
    # Every li should have both attributes for proper stimulus-autocomplete integration
    assert_select "li" do |elements|
      elements.each do |li|
        assert li["data-autocomplete-value"].present?,
          "Each <li> must have data-autocomplete-value for hidden input capture"
        assert_equal "option", li["role"],
          "Each <li> must have role='option' for accessibility"
      end
    end
  end

  test "search results include all required data attributes for each biomarker" do
    hemoglobin = Biomarker.create!(
      name: "Hemoglobin",
      code: "718-7",
      unit: "g/dL",
      ref_min: 13.5,
      ref_max: 17.5
    )

    get biomarkers_search_path(q: "Hemoglobin")

    assert_response :success
    assert_select "li" do |elements|
      elements.each do |li|
        assert li["data-autocomplete-value"].present?,
          "Must have data-autocomplete-value for ID"
        assert li["data-biomarker-name"].present?,
          "Must have data-biomarker-name for display"
        assert li["data-biomarker-code"].present?,
          "Must have data-biomarker-code for reference"
        assert li["data-biomarker-unit"].present?,
          "Must have data-biomarker-unit for auto-fill"
        assert li["data-biomarker-ref-min"].present?,
          "Must have data-biomarker-ref-min for auto-fill"
        assert li["data-biomarker-ref-max"].present?,
          "Must have data-biomarker-ref-max for auto-fill"
      end
    end
  end
end
