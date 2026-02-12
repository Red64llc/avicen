require "test_helper"

class DrugTest < ActiveSupport::TestCase
  test "validates name presence" do
    drug = Drug.new(name: nil)
    assert_not drug.valid?
    assert_includes drug.errors[:name], "can't be blank"
  end

  test "valid with name only" do
    drug = Drug.new(name: "Aspirin")
    assert drug.valid?
  end

  test "validates rxcui uniqueness" do
    existing = drugs(:aspirin)
    drug = Drug.new(name: "Duplicate Aspirin", rxcui: existing.rxcui)
    assert_not drug.valid?
    assert_includes drug.errors[:rxcui], "has already been taken"
  end

  test "allows nil rxcui for manually entered drugs" do
    drug1 = drugs(:manual_drug)
    drug2 = Drug.new(name: "Another Manual Drug", rxcui: nil)
    assert drug2.valid?
  end

  test "allows multiple drugs with nil rxcui" do
    Drug.create!(name: "Manual Drug A", rxcui: nil)
    drug2 = Drug.new(name: "Manual Drug B", rxcui: nil)
    assert drug2.valid?
  end

  test "search_by_name returns matching drugs" do
    results = Drug.search_by_name("Aspirin")
    assert_includes results, drugs(:aspirin)
    assert_not_includes results, drugs(:ibuprofen)
  end

  test "search_by_name is case-insensitive via LIKE" do
    results = Drug.search_by_name("aspirin")
    assert_includes results, drugs(:aspirin)
  end

  test "search_by_name returns partial matches" do
    results = Drug.search_by_name("Ibup")
    assert_includes results, drugs(:ibuprofen)
  end

  test "search_by_name returns empty for no match" do
    results = Drug.search_by_name("Nonexistent")
    assert_empty results
  end

  test "has_many medications association" do
    drug = drugs(:aspirin)
    assert_respond_to drug, :medications
  end

  test "restrict_with_error prevents deletion when medications exist" do
    drug = drugs(:aspirin)
    # We need a medication referencing this drug to test restrict_with_error
    # This will be fully testable after Medication model is created in task 1.3
    # For now, verify the association is configured
    assert_equal :restrict_with_error, Drug.reflect_on_association(:medications).options[:dependent]
  end
end
