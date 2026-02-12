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

  # Task 2.2: Associations
  test "belongs to user" do
    assert_respond_to BiologyReport.new, :user
  end

  test "has many test_results with dependent destroy" do
    assert_respond_to BiologyReport.new, :test_results

    # Check dependent: :destroy
    reflection = BiologyReport.reflect_on_association(:test_results)
    assert_equal :destroy, reflection.options[:dependent]
  end

  # Task 2.2: Validations
  test "validates presence of test_date" do
    user = users(:one)
    report = BiologyReport.new(user: user)
    assert_not report.valid?
    assert_includes report.errors[:test_date], "can't be blank"
  end

  test "validates presence of user_id" do
    report = BiologyReport.new(test_date: Date.today)
    assert_not report.valid?
    assert_includes report.errors[:user], "must exist"
  end

  test "valid biology report with required attributes" do
    user = users(:one)
    report = BiologyReport.new(user: user, test_date: Date.today)
    assert report.valid?
  end

  test "optional lab_name and notes" do
    user = users(:one)
    report = BiologyReport.new(user: user, test_date: Date.today, lab_name: nil, notes: nil)
    assert report.valid?
  end

  # Task 2.2: Active Storage
  test "has one attached document" do
    assert_respond_to BiologyReport.new, :document
  end

  # Task 2.2: Scopes
  test "ordered scope returns reports by test_date descending" do
    user = users(:one)
    report1 = BiologyReport.create!(user: user, test_date: Date.today - 2.days)
    report2 = BiologyReport.create!(user: user, test_date: Date.today)
    report3 = BiologyReport.create!(user: user, test_date: Date.today - 1.day)

    ordered = BiologyReport.ordered
    assert_equal [report2, report3, report1], ordered.to_a
  end

  test "by_date_range scope filters by date range" do
    user = users(:one)
    report1 = BiologyReport.create!(user: user, test_date: Date.new(2025, 1, 15))
    report2 = BiologyReport.create!(user: user, test_date: Date.new(2025, 2, 10))
    report3 = BiologyReport.create!(user: user, test_date: Date.new(2025, 3, 5))

    results = BiologyReport.by_date_range(Date.new(2025, 2, 1), Date.new(2025, 2, 28))
    assert_equal 1, results.count
    assert_includes results, report2
    assert_not_includes results, report1
    assert_not_includes results, report3
  end

  test "by_date_range scope returns all when from_date is nil" do
    user = users(:one)
    report1 = BiologyReport.create!(user: user, test_date: Date.new(2025, 1, 15))
    report2 = BiologyReport.create!(user: user, test_date: Date.new(2025, 2, 10))

    results = BiologyReport.by_date_range(nil, Date.new(2025, 3, 1))
    assert_equal 2, results.count
  end

  test "by_date_range scope returns all when to_date is nil" do
    user = users(:one)
    report1 = BiologyReport.create!(user: user, test_date: Date.new(2025, 1, 15))
    report2 = BiologyReport.create!(user: user, test_date: Date.new(2025, 2, 10))

    results = BiologyReport.by_date_range(Date.new(2025, 1, 1), nil)
    assert_equal 2, results.count
  end

  test "by_lab_name scope filters by laboratory name case-insensitively" do
    user = users(:one)
    report1 = BiologyReport.create!(user: user, test_date: Date.today, lab_name: "LabCorp")
    report2 = BiologyReport.create!(user: user, test_date: Date.today, lab_name: "Quest Diagnostics")
    report3 = BiologyReport.create!(user: user, test_date: Date.today, lab_name: "LabCorp West")

    results = BiologyReport.by_lab_name("labcorp")
    assert_equal 2, results.count
    assert_includes results, report1
    assert_includes results, report3
    assert_not_includes results, report2
  end

  test "by_lab_name scope returns all when query is blank" do
    user = users(:one)
    report1 = BiologyReport.create!(user: user, test_date: Date.today, lab_name: "LabCorp")
    report2 = BiologyReport.create!(user: user, test_date: Date.today, lab_name: "Quest")

    results = BiologyReport.by_lab_name(nil)
    assert_equal 2, results.count
  end
end
