require "test_helper"

class BiologyReportTest < ActiveSupport::TestCase
  test "biology_reports table exists" do
    assert ActiveRecord::Base.connection.table_exists?(:biology_reports)
  end

  test "biology_reports table has required columns" do
    assert_includes BiologyReport.column_names, "user_id"
    assert_includes BiologyReport.column_names, "test_date"
    assert_includes BiologyReport.column_names, "lab_name"
    assert_includes BiologyReport.column_names, "notes"
    assert_includes BiologyReport.column_names, "created_at"
    assert_includes BiologyReport.column_names, "updated_at"
  end

  test "biology_reports table has indexes" do
    indexes = ActiveRecord::Base.connection.indexes(:biology_reports)
    index_names = indexes.map(&:name)

    assert_includes index_names, "index_biology_reports_on_user_id"
    assert_includes index_names, "index_biology_reports_on_test_date"
    assert_includes index_names, "index_biology_reports_on_user_id_and_test_date"
  end

  test "biology_reports table has foreign key to users" do
    foreign_keys = ActiveRecord::Base.connection.foreign_keys(:biology_reports)
    user_fk = foreign_keys.find { |fk| fk.column == "user_id" }

    assert_not_nil user_fk, "user_id foreign key should exist"
    assert_equal "users", user_fk.to_table
    assert_equal :cascade, user_fk.on_delete
  end

  test "biology_reports columns have correct types" do
    columns = BiologyReport.columns_hash

    assert_equal :integer, columns["user_id"].type
    assert_equal :date, columns["test_date"].type
    assert_equal :string, columns["lab_name"].type
    assert_equal :text, columns["notes"].type
  end

  test "biology_reports columns have correct null constraints" do
    columns = BiologyReport.columns_hash

    assert_not columns["user_id"].null
    assert_not columns["test_date"].null
    assert columns["lab_name"].null
    assert columns["notes"].null
  end
end
