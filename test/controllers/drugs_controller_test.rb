require "test_helper"

class DrugsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "search requires authentication" do
    sign_out
    get drugs_search_path(q: "Aspirin")
    assert_redirected_to new_session_path
  end

  test "search returns HTML li fragments for matching drugs" do
    get drugs_search_path(q: "Aspirin")

    assert_response :success
    assert_select "li[data-autocomplete-value]", count: 1
    assert_select "li[data-autocomplete-value=?]", drugs(:aspirin).id.to_s
    assert_select "li", text: /Aspirin/
  end

  test "search returns multiple results for broad query" do
    get drugs_search_path(q: "in") # matches "Aspirin", "Ibuprofen...Tablet"

    assert_response :success
    assert_select "li[data-autocomplete-value]", minimum: 1
  end

  test "search returns empty response for no matches" do
    stub_request(:get, /rxnav\.nlm\.nih\.gov/).to_return(
      status: 200,
      body: { drugGroup: { conceptGroup: [] } }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    get drugs_search_path(q: "Zzzzzznonexistent")

    assert_response :success
    assert_select "li", count: 0
  end

  test "search returns empty response for query shorter than 2 characters" do
    get drugs_search_path(q: "a")

    assert_response :success
    assert_empty response.body.strip
  end

  test "search returns empty response for empty query" do
    get drugs_search_path(q: "")

    assert_response :success
    assert_empty response.body.strip
  end

  test "search returns empty response when q parameter is missing" do
    get drugs_search_path

    assert_response :success
    assert_empty response.body.strip
  end
end
