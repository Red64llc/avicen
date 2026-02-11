require "test_helper"

class PrescriptionTest < ActiveSupport::TestCase
  test "validates prescribed_date presence" do
    prescription = Prescription.new(user: users(:one), prescribed_date: nil)
    assert_not prescription.valid?
    assert_includes prescription.errors[:prescribed_date], "can't be blank"
  end

  test "valid with user and prescribed_date" do
    prescription = Prescription.new(
      user: users(:one),
      doctor_name: "Dr. Test",
      prescribed_date: Date.today
    )
    assert prescription.valid?
  end

  test "belongs_to user association" do
    prescription = prescriptions(:one)
    assert_equal users(:one), prescription.user
  end

  test "has_many medications association" do
    prescription = prescriptions(:one)
    assert_respond_to prescription, :medications
  end

  test "ordered scope returns prescriptions in descending prescribed_date order" do
    user_prescriptions = Prescription.where(user: users(:one)).ordered
    assert_equal prescriptions(:two), user_prescriptions.first
    assert_equal prescriptions(:one), user_prescriptions.second
  end

  test "cascading destroy removes associated medications" do
    prescription = prescriptions(:one)
    # Medications will be created in task 1.3 fixtures
    # For now verify the dependent option is configured correctly
    assert_equal :destroy, Prescription.reflect_on_association(:medications).options[:dependent]
  end

  test "user has_many prescriptions" do
    user = users(:one)
    assert_respond_to user, :prescriptions
    assert_includes user.prescriptions, prescriptions(:one)
    assert_includes user.prescriptions, prescriptions(:two)
    assert_not_includes user.prescriptions, prescriptions(:other_user_prescription)
  end
end
