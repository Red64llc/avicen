require "test_helper"

class BiomarkerSeedsTest < ActiveSupport::TestCase
  setup do
    # Clear biomarkers before testing seeds
    Biomarker.delete_all
  end

  test "seed data creates biomarkers" do
    # Load seed data
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.count >= 20, "Should have at least 20 biomarkers seeded"
  end

  test "seed data includes CBC biomarkers" do
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.exists?(name: "Hemoglobin"), "Should include Hemoglobin"
    assert Biomarker.exists?(name: "White Blood Cell Count"), "Should include WBC"
    assert Biomarker.exists?(name: "Platelet Count"), "Should include Platelets"
  end

  test "seed data includes metabolic panel biomarkers" do
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.exists?(name: "Glucose"), "Should include Glucose"
    assert Biomarker.exists?(name: "Creatinine"), "Should include Creatinine"
    assert Biomarker.exists?(name: "Sodium"), "Should include Sodium"
    assert Biomarker.exists?(name: "Potassium"), "Should include Potassium"
  end

  test "seed data includes lipid panel biomarkers" do
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.exists?(name: "Total Cholesterol"), "Should include Total Cholesterol"
    assert Biomarker.exists?(name: "LDL Cholesterol"), "Should include LDL"
    assert Biomarker.exists?(name: "HDL Cholesterol"), "Should include HDL"
    assert Biomarker.exists?(name: "Triglycerides"), "Should include Triglycerides"
  end

  test "seed data includes thyroid biomarkers" do
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.exists?(name: "TSH"), "Should include TSH"
    assert Biomarker.exists?(name: "Free T4"), "Should include Free T4"
  end

  test "seed data includes vitamin biomarkers" do
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.exists?(name: "Vitamin D"), "Should include Vitamin D"
    assert Biomarker.exists?(name: "Vitamin B12"), "Should include Vitamin B12"
  end

  test "biomarkers have valid codes" do
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    Biomarker.all.each do |biomarker|
      assert_not_nil biomarker.code
      assert biomarker.code.length > 0, "Code should not be empty for #{biomarker.name}"
    end
  end

  test "biomarkers have valid units" do
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    Biomarker.all.each do |biomarker|
      assert_not_nil biomarker.unit
      assert biomarker.unit.length > 0, "Unit should not be empty for #{biomarker.name}"
    end
  end

  test "biomarkers have valid reference ranges" do
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    Biomarker.all.each do |biomarker|
      assert_not_nil biomarker.ref_min
      assert_not_nil biomarker.ref_max
      assert biomarker.ref_min < biomarker.ref_max,
             "ref_min should be less than ref_max for #{biomarker.name}"
    end
  end

  test "seeding is idempotent" do
    load Rails.root.join("db", "seeds", "biomarkers.rb")
    count_first = Biomarker.count

    load Rails.root.join("db", "seeds", "biomarkers.rb")
    count_second = Biomarker.count

    assert_equal count_first, count_second, "Running seeds twice should not duplicate biomarkers"
  end
end
