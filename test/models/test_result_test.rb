require "test_helper"

class TestResultTest < ActiveSupport::TestCase
  test "test_results table exists" do
    assert ActiveRecord::Base.connection.table_exists?(:test_results)
  end

  test "test_results table has required columns" do
    assert_includes TestResult.column_names, "biology_report_id"
    assert_includes TestResult.column_names, "biomarker_id"
    assert_includes TestResult.column_names, "value"
    assert_includes TestResult.column_names, "unit"
    assert_includes TestResult.column_names, "ref_min"
    assert_includes TestResult.column_names, "ref_max"
    assert_includes TestResult.column_names, "out_of_range"
    assert_includes TestResult.column_names, "created_at"
    assert_includes TestResult.column_names, "updated_at"
  end

  test "test_results table has indexes" do
    indexes = ActiveRecord::Base.connection.indexes(:test_results)
    index_names = indexes.map(&:name)

    assert_includes index_names, "index_test_results_on_biology_report_id"
    assert_includes index_names, "index_test_results_on_biomarker_id"
    assert_includes index_names, "index_test_results_on_out_of_range"
  end

  test "test_results table has foreign keys" do
    foreign_keys = ActiveRecord::Base.connection.foreign_keys(:test_results)

    biology_report_fk = foreign_keys.find { |fk| fk.column == "biology_report_id" }
    assert_not_nil biology_report_fk, "biology_report_id foreign key should exist"
    assert_equal "biology_reports", biology_report_fk.to_table
    assert_equal :cascade, biology_report_fk.on_delete

    biomarker_fk = foreign_keys.find { |fk| fk.column == "biomarker_id" }
    assert_not_nil biomarker_fk, "biomarker_id foreign key should exist"
    assert_equal "biomarkers", biomarker_fk.to_table
    assert_equal :restrict, biomarker_fk.on_delete
  end

  test "test_results columns have correct types" do
    columns = TestResult.columns_hash

    assert_equal :integer, columns["biology_report_id"].type
    assert_equal :integer, columns["biomarker_id"].type
    assert_equal :decimal, columns["value"].type
    assert_equal :string, columns["unit"].type
    assert_equal :decimal, columns["ref_min"].type
    assert_equal :decimal, columns["ref_max"].type
    assert_equal :boolean, columns["out_of_range"].type
  end

  test "test_results columns have correct null constraints" do
    columns = TestResult.columns_hash

    assert_not columns["biology_report_id"].null
    assert_not columns["biomarker_id"].null
    assert_not columns["value"].null
    assert_not columns["unit"].null
    assert columns["ref_min"].null
    assert columns["ref_max"].null
    assert columns["out_of_range"].null
  end
end
