require "test_helper"

class BiomarkerSearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)

    # Create test biomarkers
    @glucose = Biomarker.create!(
      name: "Glucose",
      code: "2345-7",
      unit: "mg/dL",
      ref_min: 70.0,
      ref_max: 100.0
    )

    @hemoglobin = Biomarker.create!(
      name: "Hemoglobin",
      code: "718-7",
      unit: "g/dL",
      ref_min: 13.5,
      ref_max: 17.5
    )

    @cholesterol = Biomarker.create!(
      name: "Total Cholesterol",
      code: "2093-3",
      unit: "mg/dL",
      ref_min: 0,
      ref_max: 200.0
    )
  end

  test "search requires authentication" do
    sign_out
    get biomarkers_search_path(q: "Glucose")
    assert_redirected_to new_session_path
  end

  test "search returns HTML li fragments for matching biomarkers by name" do
    get biomarkers_search_path(q: "Glucose")

    assert_response :success
    assert_select "li[role='option']", count: 1
    assert_select "li[data-autocomplete-value='#{@glucose.id}']"
    assert_select "li[data-biomarker-name='Glucose']"
    assert_select "li[data-biomarker-code='2345-7']"
    assert_select "li[data-biomarker-unit='mg/dL']"
    assert_select "li[data-biomarker-ref-min='70.0']"
    assert_select "li[data-biomarker-ref-max='100.0']"
    assert_select "li", text: /Glucose/
  end

  test "search returns HTML li fragments for matching biomarkers by code" do
    get biomarkers_search_path(q: "718-7")

    assert_response :success
    assert_select "li[role='option']", count: 1
    assert_select "li[data-autocomplete-value='#{@hemoglobin.id}']"
    assert_select "li", text: /Hemoglobin/
  end

  test "search returns multiple results for broad query" do
    get biomarkers_search_path(q: "ol") # matches "Hemoglobin", "Cholesterol"

    assert_response :success
    assert_select "li[role='option']", minimum: 2
  end

  test "search is case-insensitive" do
    get biomarkers_search_path(q: "glucose")

    assert_response :success
    assert_select "li[data-autocomplete-value='#{@glucose.id}']"
  end

  test "search returns empty response for no matches" do
    get biomarkers_search_path(q: "Zzzzzznonexistent")

    assert_response :success
    assert_select "li", count: 0
  end

  test "search returns empty response for query shorter than 2 characters" do
    get biomarkers_search_path(q: "a")

    assert_response :success
    assert_empty response.body.strip
  end

  test "search returns empty response for empty query" do
    get biomarkers_search_path(q: "")

    assert_response :success
    assert_empty response.body.strip
  end

  test "search returns empty response when q parameter is missing" do
    get biomarkers_search_path

    assert_response :success
    assert_empty response.body.strip
  end

  test "search limits results to 10 matches" do
    # Create 15 biomarkers with similar names
    15.times do |i|
      Biomarker.create!(
        name: "Test Biomarker #{i}",
        code: "TEST-#{i}",
        unit: "unit",
        ref_min: 0,
        ref_max: 100
      )
    end

    get biomarkers_search_path(q: "Test")

    assert_response :success
    assert_select "li[role='option']", count: 10
  end
end
