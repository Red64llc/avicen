require "test_helper"

class BiomarkerTest < ActiveSupport::TestCase
  # Schema tests (from Task 1)
  test "biomarkers table exists" do
    assert ActiveRecord::Base.connection.table_exists?(:biomarkers)
  end

  test "biomarkers table has required columns" do
    assert_includes Biomarker.column_names, "name"
    assert_includes Biomarker.column_names, "code"
    assert_includes Biomarker.column_names, "unit"
    assert_includes Biomarker.column_names, "ref_min"
    assert_includes Biomarker.column_names, "ref_max"
    assert_includes Biomarker.column_names, "created_at"
    assert_includes Biomarker.column_names, "updated_at"
  end

  test "biomarkers table has indexes" do
    indexes = ActiveRecord::Base.connection.indexes(:biomarkers)
    index_names = indexes.map(&:name)

    assert_includes index_names, "index_biomarkers_on_code"
    assert_includes index_names, "index_biomarkers_on_name"

    # Verify code index is unique
    code_index = indexes.find { |idx| idx.name == "index_biomarkers_on_code" }
    assert code_index.unique, "code index should be unique"
  end

  test "biomarkers columns have correct types" do
    columns = Biomarker.columns_hash

    assert_equal :string, columns["name"].type
    assert_equal :string, columns["code"].type
    assert_equal :string, columns["unit"].type
    assert_equal :decimal, columns["ref_min"].type
    assert_equal :decimal, columns["ref_max"].type
  end

  test "biomarkers columns have correct null constraints" do
    columns = Biomarker.columns_hash

    assert_not columns["name"].null
    assert_not columns["code"].null
    assert_not columns["unit"].null
    assert_not columns["ref_min"].null
    assert_not columns["ref_max"].null
  end

  # Task 2.1: Validations
  test "validates presence of name" do
    biomarker = Biomarker.new(code: "TEST", unit: "mg/dL", ref_min: 10, ref_max: 20)
    assert_not biomarker.valid?
    assert_includes biomarker.errors[:name], "can't be blank"
  end

  test "validates presence of code" do
    biomarker = Biomarker.new(name: "Test", unit: "mg/dL", ref_min: 10, ref_max: 20)
    assert_not biomarker.valid?
    assert_includes biomarker.errors[:code], "can't be blank"
  end

  test "validates presence of unit" do
    biomarker = Biomarker.new(name: "Test", code: "TEST", ref_min: 10, ref_max: 20)
    assert_not biomarker.valid?
    assert_includes biomarker.errors[:unit], "can't be blank"
  end

  test "validates presence of ref_min" do
    biomarker = Biomarker.new(name: "Test", code: "TEST", unit: "mg/dL", ref_max: 20)
    assert_not biomarker.valid?
    assert_includes biomarker.errors[:ref_min], "can't be blank"
  end

  test "validates presence of ref_max" do
    biomarker = Biomarker.new(name: "Test", code: "TEST", unit: "mg/dL", ref_min: 10)
    assert_not biomarker.valid?
    assert_includes biomarker.errors[:ref_max], "can't be blank"
  end

  test "validates uniqueness of code case-insensitively" do
    Biomarker.create!(name: "Test", code: "TEST123", unit: "mg/dL", ref_min: 10, ref_max: 20)
    duplicate = Biomarker.new(name: "Test 2", code: "test123", unit: "mg/dL", ref_min: 10, ref_max: 20)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "validates numericality of ref_min" do
    biomarker = Biomarker.new(name: "Test", code: "TEST", unit: "mg/dL", ref_min: "invalid", ref_max: 20)
    assert_not biomarker.valid?
    assert_includes biomarker.errors[:ref_min], "is not a number"
  end

  test "validates numericality of ref_max" do
    biomarker = Biomarker.new(name: "Test", code: "TEST", unit: "mg/dL", ref_min: 10, ref_max: "invalid")
    assert_not biomarker.valid?
    assert_includes biomarker.errors[:ref_max], "is not a number"
  end

  test "valid biomarker with all required attributes" do
    biomarker = Biomarker.new(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    assert biomarker.valid?
  end

  # Task 2.1: Associations
  test "has many test_results" do
    assert_respond_to Biomarker.new, :test_results
  end

  # Task 2.1: Scopes and search
  test "search scope finds biomarkers by name case-insensitively" do
    # Use unique names that won't match fixtures
    biomarker1 = Biomarker.create!(name: "UniqueZymarker", code: "UZM1", unit: "mg/dL", ref_min: 70, ref_max: 100)
    Biomarker.create!(name: "OtherMarker", code: "OTH1", unit: "g/dL", ref_min: 12, ref_max: 16)

    results = Biomarker.search("uniquezymarker")
    assert_equal 1, results.count
    assert_equal "UniqueZymarker", results.first.name
  end

  test "search scope finds biomarkers by code case-insensitively" do
    # Use unique codes that won't match fixtures
    biomarker1 = Biomarker.create!(name: "UniqueZymarker", code: "UZM2", unit: "mg/dL", ref_min: 70, ref_max: 100)
    Biomarker.create!(name: "OtherMarker", code: "OTH2", unit: "g/dL", ref_min: 12, ref_max: 16)

    results = Biomarker.search("uzm2")
    assert_equal 1, results.count
    assert_equal "UniqueZymarker", results.first.name
  end

  test "search scope finds biomarkers by partial match" do
    # Use unique names that won't match fixtures
    biomarker1 = Biomarker.create!(name: "UniqueZymarkerFull", code: "UZF1", unit: "mg/dL", ref_min: 70, ref_max: 100)
    Biomarker.create!(name: "OtherDifferentMarker", code: "ODM1", unit: "%", ref_min: 4, ref_max: 6)

    results = Biomarker.search("uniquezy")
    assert_equal 1, results.count
    assert_equal "UniqueZymarkerFull", results.first.name
  end

  test "autocomplete_search returns top 10 matches" do
    15.times do |i|
      Biomarker.create!(name: "Test #{i}", code: "TEST#{i}", unit: "mg/dL", ref_min: 10, ref_max: 20)
    end

    results = Biomarker.autocomplete_search("test")
    assert_equal 10, results.count
  end

  test "autocomplete_search returns empty array for blank query" do
    Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)

    results = Biomarker.autocomplete_search("")
    assert_equal 0, results.count
  end

  test "autocomplete_search returns empty array for nil query" do
    Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)

    results = Biomarker.autocomplete_search(nil)
    assert_equal 0, results.count
  end
end
