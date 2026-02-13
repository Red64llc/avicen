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

  # Task 2.3: Associations
  test "belongs to biology_report" do
    assert_respond_to TestResult.new, :biology_report
  end

  test "belongs to biomarker" do
    assert_respond_to TestResult.new, :biomarker
  end

  # Task 2.3: Validations
  test "validates presence of biomarker_id" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    result = TestResult.new(biology_report: report, value: 100, unit: "mg/dL")
    assert_not result.valid?
    assert_includes result.errors[:biomarker], "must exist"
  end

  test "validates presence of value" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.new(biology_report: report, biomarker: biomarker, unit: "mg/dL")
    assert_not result.valid?
    assert_includes result.errors[:value], "can't be blank"
  end

  test "validates presence of unit" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.new(biology_report: report, biomarker: biomarker, value: 100)
    assert_not result.valid?
    assert_includes result.errors[:unit], "can't be blank"
  end

  test "validates numericality of value" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.new(biology_report: report, biomarker: biomarker, value: "invalid", unit: "mg/dL")
    assert_not result.valid?
    assert_includes result.errors[:value], "is not a number"
  end

  test "valid test result with all required attributes" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.new(biology_report: report, biomarker: biomarker, value: 95, unit: "mg/dL")
    assert result.valid?
  end

  # Task 2.3: Out-of-range calculation
  test "calculates out_of_range flag on save when value is below ref_min" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.create!(biology_report: report, biomarker: biomarker, value: 65, unit: "mg/dL", ref_min: 70, ref_max: 100)

    assert_equal true, result.out_of_range
  end

  test "calculates out_of_range flag on save when value is above ref_max" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.create!(biology_report: report, biomarker: biomarker, value: 110, unit: "mg/dL", ref_min: 70, ref_max: 100)

    assert_equal true, result.out_of_range
  end

  test "calculates out_of_range flag as false when value is within range" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.create!(biology_report: report, biomarker: biomarker, value: 85, unit: "mg/dL", ref_min: 70, ref_max: 100)

    assert_equal false, result.out_of_range
  end

  test "calculates out_of_range flag as false when value equals ref_min" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.create!(biology_report: report, biomarker: biomarker, value: 70, unit: "mg/dL", ref_min: 70, ref_max: 100)

    assert_equal false, result.out_of_range
  end

  test "calculates out_of_range flag as false when value equals ref_max" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.create!(biology_report: report, biomarker: biomarker, value: 100, unit: "mg/dL", ref_min: 70, ref_max: 100)

    assert_equal false, result.out_of_range
  end

  test "calculates out_of_range flag as nil when ref_min or ref_max is nil" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.create!(biology_report: report, biomarker: biomarker, value: 85, unit: "mg/dL", ref_min: nil, ref_max: nil)

    assert_nil result.out_of_range
  end

  test "recalculates out_of_range flag on update" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Glucose", code: "GLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    result = TestResult.create!(biology_report: report, biomarker: biomarker, value: 85, unit: "mg/dL", ref_min: 70, ref_max: 100)

    assert_equal false, result.out_of_range

    result.update!(value: 110)
    assert_equal true, result.out_of_range
  end

  # Task 2.3: Scopes
  test "out_of_range scope filters results by out_of_range status" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Test Glucose", code: "TGLU", unit: "mg/dL", ref_min: 70, ref_max: 100)

    in_range = TestResult.create!(biology_report: report, biomarker: biomarker, value: 85, unit: "mg/dL", ref_min: 70, ref_max: 100)
    out_of_range_low = TestResult.create!(biology_report: report, biomarker: biomarker, value: 65, unit: "mg/dL", ref_min: 70, ref_max: 100)
    out_of_range_high = TestResult.create!(biology_report: report, biomarker: biomarker, value: 110, unit: "mg/dL", ref_min: 70, ref_max: 100)

    # Scope to just the test report to avoid fixture interference
    out_of_range_results = report.test_results.out_of_range
    assert_equal 2, out_of_range_results.count
    assert_includes out_of_range_results, out_of_range_low
    assert_includes out_of_range_results, out_of_range_high
    assert_not_includes out_of_range_results, in_range
  end

  test "in_range scope filters results by in_range status" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    biomarker = Biomarker.create!(name: "Test Glucose", code: "TGLU", unit: "mg/dL", ref_min: 70, ref_max: 100)

    in_range = TestResult.create!(biology_report: report, biomarker: biomarker, value: 85, unit: "mg/dL", ref_min: 70, ref_max: 100)
    out_of_range = TestResult.create!(biology_report: report, biomarker: biomarker, value: 110, unit: "mg/dL", ref_min: 70, ref_max: 100)

    # Scope to just the test report to avoid fixture interference
    in_range_results = report.test_results.in_range
    assert_equal 1, in_range_results.count
    assert_includes in_range_results, in_range
    assert_not_includes in_range_results, out_of_range
  end

  test "for_biomarker scope groups results by biomarker" do
    user = users(:one)
    report = BiologyReport.create!(user: user, test_date: Date.today)
    glucose = Biomarker.create!(name: "Test Glucose", code: "TGLU", unit: "mg/dL", ref_min: 70, ref_max: 100)
    hemoglobin = Biomarker.create!(name: "Test Hemoglobin", code: "THGB", unit: "g/dL", ref_min: 12, ref_max: 16)

    result1 = TestResult.create!(biology_report: report, biomarker: glucose, value: 85, unit: "mg/dL", ref_min: 70, ref_max: 100)
    result2 = TestResult.create!(biology_report: report, biomarker: hemoglobin, value: 14, unit: "g/dL", ref_min: 12, ref_max: 16)

    # Scope to just the test report to avoid fixture interference
    glucose_results = report.test_results.for_biomarker(glucose.id)
    assert_equal 1, glucose_results.count
    assert_includes glucose_results, result1
    assert_not_includes glucose_results, result2
  end
end
