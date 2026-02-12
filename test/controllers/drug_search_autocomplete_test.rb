require "test_helper"

# Tests that the drug search endpoint returns HTML fragments compatible with
# the stimulus-autocomplete library and the drug-search Stimulus controller.
#
# The drug-search controller wraps stimulus-autocomplete, so the server must
# return <li> elements with:
#   - data-autocomplete-value set to the Drug ID (for hidden input)
#   - role="option" for accessibility
#   - visible text content showing the drug name (for text input display)
#
# Requirements: 1.4, 3.5
class DrugSearchAutocompleteTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "search results include role=option for stimulus-autocomplete compatibility" do
    get drugs_search_path(q: "Aspirin")

    assert_response :success
    assert_select "li[role='option']", minimum: 1
  end

  test "search results include data-autocomplete-value with drug ID for hidden input capture" do
    get drugs_search_path(q: "Aspirin")

    assert_response :success
    aspirin = drugs(:aspirin)
    assert_select "li[data-autocomplete-value='#{aspirin.id}']", count: 1
    assert_select "li[data-autocomplete-value='#{aspirin.id}']", text: /Aspirin/
  end

  test "search results display drug name as text content for text input display" do
    get drugs_search_path(q: "Ibuprofen")

    assert_response :success
    assert_select "li", text: /Ibuprofen 200mg Oral Tablet/
  end

  test "each search result li has both data-autocomplete-value and role=option" do
    get drugs_search_path(q: "in") # matches multiple drugs

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
end
