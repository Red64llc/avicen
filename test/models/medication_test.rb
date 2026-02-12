require "test_helper"

class MedicationTest < ActiveSupport::TestCase
  test "validates dosage presence" do
    medication = Medication.new(
      prescription: prescriptions(:one),
      drug: drugs(:aspirin),
      dosage: nil,
      form: "tablet"
    )
    assert_not medication.valid?
    assert_includes medication.errors[:dosage], "can't be blank"
  end

  test "validates form presence" do
    medication = Medication.new(
      prescription: prescriptions(:one),
      drug: drugs(:aspirin),
      dosage: "50mg",
      form: nil
    )
    assert_not medication.valid?
    assert_includes medication.errors[:form], "can't be blank"
  end

  test "valid with all required attributes" do
    medication = Medication.new(
      prescription: prescriptions(:one),
      drug: drugs(:aspirin),
      dosage: "50mg",
      form: "tablet"
    )
    assert medication.valid?
  end

  test "belongs_to prescription" do
    medication = medications(:aspirin_morning)
    assert_equal prescriptions(:one), medication.prescription
  end

  test "belongs_to drug" do
    medication = medications(:aspirin_morning)
    assert_equal drugs(:aspirin), medication.drug
  end

  test "has_many medication_schedules" do
    medication = medications(:aspirin_morning)
    assert_respond_to medication, :medication_schedules
    assert_equal :destroy, Medication.reflect_on_association(:medication_schedules).options[:dependent]
  end

  test "has_many medication_logs" do
    medication = medications(:aspirin_morning)
    assert_respond_to medication, :medication_logs
    assert_equal :destroy, Medication.reflect_on_association(:medication_logs).options[:dependent]
  end

  test "active scope returns only active medications" do
    active = Medication.active
    assert_includes active, medications(:aspirin_morning)
    assert_includes active, medications(:ibuprofen_evening)
    assert_not_includes active, medications(:inactive_medication)
  end

  test "inactive scope returns only inactive medications" do
    inactive = Medication.inactive
    assert_includes inactive, medications(:inactive_medication)
    assert_not_includes inactive, medications(:aspirin_morning)
  end

  test "defaults to active true" do
    medication = Medication.new(
      prescription: prescriptions(:one),
      drug: drugs(:aspirin),
      dosage: "50mg",
      form: "tablet"
    )
    assert medication.active
  end

  test "prescription cascading destroy removes medications" do
    prescription = prescriptions(:one)
    medication_count = prescription.medications.count
    assert medication_count > 0

    assert_difference("Medication.count", -medication_count) do
      prescription.destroy
    end
  end
end
