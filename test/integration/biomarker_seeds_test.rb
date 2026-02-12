require "test_helper"

class BiomarkerSeedsTest < ActiveSupport::TestCase
  test "biomarker seed data loads successfully" do
    # Clear existing data
    Biomarker.delete_all

    # Load seed data
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    # Verify biomarkers were created
    assert Biomarker.count >= 20, "Expected at least 20 biomarkers, got #{Biomarker.count}"
    assert Biomarker.count <= 30, "Expected at most 30 biomarkers, got #{Biomarker.count}"
  end

  test "seed data includes CBC panel biomarkers" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    # Verify CBC markers exist
    assert Biomarker.exists?(code: "718-7"), "Hemoglobin biomarker should exist"
    assert Biomarker.exists?(code: "6690-2"), "WBC biomarker should exist"
    assert Biomarker.exists?(code: "777-3"), "Platelet biomarker should exist"
  end

  test "seed data includes metabolic panel biomarkers" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    # Verify metabolic markers
    assert Biomarker.exists?(code: "2345-7"), "Glucose biomarker should exist"
    assert Biomarker.exists?(code: "2160-0"), "Creatinine biomarker should exist"
    assert Biomarker.exists?(code: "2951-2"), "Sodium biomarker should exist"
    assert Biomarker.exists?(code: "2823-3"), "Potassium biomarker should exist"
  end

  test "seed data includes lipid panel biomarkers" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    # Verify lipid markers
    assert Biomarker.exists?(code: "2093-3"), "Total Cholesterol biomarker should exist"
    assert Biomarker.exists?(code: "2089-1"), "LDL Cholesterol biomarker should exist"
    assert Biomarker.exists?(code: "2085-9"), "HDL Cholesterol biomarker should exist"
    assert Biomarker.exists?(code: "2571-8"), "Triglycerides biomarker should exist"
  end

  test "seed data includes thyroid biomarkers" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.exists?(code: "3016-3"), "TSH biomarker should exist"
    assert Biomarker.exists?(code: "3024-7"), "Free T4 biomarker should exist"
  end

  test "seed data includes vitamin biomarkers" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.exists?(code: "1989-3"), "Vitamin D biomarker should exist"
    assert Biomarker.exists?(code: "2132-9"), "Vitamin B12 biomarker should exist"
  end

  test "seed data includes liver function biomarkers" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.exists?(code: "1742-6"), "ALT biomarker should exist"
    assert Biomarker.exists?(code: "1920-8"), "AST biomarker should exist"
  end

  test "seed data includes inflammation biomarkers" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    assert Biomarker.exists?(code: "1988-5"), "CRP biomarker should exist"
  end

  test "biomarkers have valid LOINC codes" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    Biomarker.all.each do |biomarker|
      assert biomarker.code.present?, "Biomarker #{biomarker.name} should have a code"
      assert biomarker.code.match?(/^\d+-\d+$/), "Biomarker #{biomarker.name} code should be LOINC format (e.g., '718-7')"
    end
  end

  test "biomarkers have valid reference ranges" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    Biomarker.all.each do |biomarker|
      assert biomarker.ref_min.present?, "Biomarker #{biomarker.name} should have ref_min"
      assert biomarker.ref_max.present?, "Biomarker #{biomarker.name} should have ref_max"
      assert biomarker.ref_min < biomarker.ref_max, 
        "Biomarker #{biomarker.name} ref_min (#{biomarker.ref_min}) should be less than ref_max (#{biomarker.ref_max})"
    end
  end

  test "biomarkers have valid units" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    Biomarker.all.each do |biomarker|
      assert biomarker.unit.present?, "Biomarker #{biomarker.name} should have a unit"
    end
  end

  test "seed data is idempotent" do
    Biomarker.delete_all
    
    # Load seeds twice
    load Rails.root.join("db", "seeds", "biomarkers.rb")
    first_count = Biomarker.count
    
    load Rails.root.join("db", "seeds", "biomarkers.rb")
    second_count = Biomarker.count

    assert_equal first_count, second_count, "Running seeds twice should not duplicate biomarkers"
  end

  test "specific biomarker data is correct" do
    Biomarker.delete_all
    load Rails.root.join("db", "seeds", "biomarkers.rb")

    # Check hemoglobin details
    hemoglobin = Biomarker.find_by(code: "718-7")
    assert_equal "Hemoglobin", hemoglobin.name
    assert_equal "g/dL", hemoglobin.unit
    assert hemoglobin.ref_min > 0
    assert hemoglobin.ref_max > hemoglobin.ref_min

    # Check glucose details
    glucose = Biomarker.find_by(code: "2345-7")
    assert_equal "Glucose", glucose.name
    assert_equal "mg/dL", glucose.unit
    assert_equal 70, glucose.ref_min.to_i
    assert_equal 100, glucose.ref_max.to_i
  end
end
