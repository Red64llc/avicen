require "application_system_test_case"

# System tests for the drug-search Stimulus controller integration with
# stimulus-autocomplete. These tests verify end-to-end autocomplete behavior:
#   - The autocomplete fetches results from /drugs/search
#   - The hidden input captures the selected Drug ID
#   - The text input displays the selected drug name
#
# Note: These tests require the drug search test page at /drugs/search_test.
# This route is available only in the test environment and renders a standalone
# drug search widget for isolated component testing.
#
# Requirements: 1.4, 3.5
class DrugSearchAutocompleteTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @aspirin = drugs(:aspirin)
  end

  test "drug search autocomplete widget renders with correct data attributes" do
    sign_in_as_system(@user)
    visit drugs_search_test_path

    # Verify the controller element exists with proper data attributes
    assert_selector "[data-controller='drug-search']"
    assert_selector "[data-drug-search-url-value='/drugs/search']"
    assert_selector "input[data-drug-search-target='input']"
    assert_selector "input[type='hidden'][data-drug-search-target='hidden']"
    assert_selector "ul[data-drug-search-target='results']"
  end

  test "typing in drug search field triggers autocomplete and displays matching results" do
    sign_in_as_system(@user)
    visit drugs_search_test_path

    # Type a search query (minimum 2 characters per design)
    fill_in "Drug name", with: "Aspirin"

    # Wait for autocomplete results to appear (stimulus-autocomplete fetches from server)
    assert_selector "li[role='option']", text: "Aspirin", wait: 5
  end

  test "selecting a drug from autocomplete captures Drug ID in hidden input" do
    sign_in_as_system(@user)
    visit drugs_search_test_path

    # Type and wait for results
    fill_in "Drug name", with: "Aspirin"
    assert_selector "li[role='option']", wait: 5

    # Click the matching result
    find("li[role='option']", text: "Aspirin").click

    # Verify the hidden input has the drug ID
    hidden_input = find("input[data-drug-search-target='hidden']", visible: false)
    assert_equal @aspirin.id.to_s, hidden_input.value,
      "Hidden input should capture the selected Drug ID"
  end

  test "selecting a drug displays the drug name in the visible text input" do
    sign_in_as_system(@user)
    visit drugs_search_test_path

    # Type and wait for results
    fill_in "Drug name", with: "Aspirin"
    assert_selector "li[role='option']", wait: 5

    # Click the matching result
    find("li[role='option']", text: "Aspirin").click

    # Verify the text input shows the drug name
    input = find("input[data-drug-search-target='input']")
    assert_equal "Aspirin", input.value,
      "Text input should display the selected drug name"
  end

  test "short queries do not trigger autocomplete results" do
    sign_in_as_system(@user)
    visit drugs_search_test_path

    # Type only 1 character (below the 2-character minimum)
    fill_in "Drug name", with: "A"

    # Wait a moment and verify no results appear
    sleep 1
    assert_no_selector "li[role='option']"
  end
end
