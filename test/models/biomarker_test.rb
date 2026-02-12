require "test_helper"

class BiomarkerTest < ActiveSupport::TestCase
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
end
