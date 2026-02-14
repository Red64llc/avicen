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

  # Task 2.1: Extraction support for document scanning
  test "has extraction_status column with integer type" do
    columns = Prescription.columns_hash
    assert_includes Prescription.column_names, "extraction_status"
    assert_equal :integer, columns["extraction_status"].type
  end

  test "extraction_status defaults to manual (0)" do
    prescription = Prescription.new(user: users(:one), prescribed_date: Date.today)
    assert_equal 0, prescription.extraction_status_before_type_cast
    assert prescription.extraction_manual?
  end

  test "extraction_status cannot be null" do
    columns = Prescription.columns_hash
    assert_not columns["extraction_status"].null
  end

  test "has extracted_data jsonb column" do
    columns = Prescription.columns_hash
    assert_includes Prescription.column_names, "extracted_data"
    # SQLite uses json type
    assert_includes [ :json, :jsonb ], columns["extracted_data"].type
  end

  test "extracted_data is nullable" do
    columns = Prescription.columns_hash
    assert columns["extracted_data"].null
  end

  test "extraction_status enum has all required values" do
    expected_values = %w[manual pending processing extracted confirmed failed]
    assert_equal expected_values, Prescription.extraction_statuses.keys
  end

  test "extraction_status enum values map correctly" do
    expected_mapping = {
      "manual" => 0,
      "pending" => 1,
      "processing" => 2,
      "extracted" => 3,
      "confirmed" => 4,
      "failed" => 5
    }
    assert_equal expected_mapping, Prescription.extraction_statuses
  end

  test "extraction_status enum uses extraction prefix" do
    prescription = Prescription.new(user: users(:one), prescribed_date: Date.today)

    # With prefix, methods should be extraction_manual?, extraction_pending?, etc.
    assert_respond_to prescription, :extraction_manual?
    assert_respond_to prescription, :extraction_pending?
    assert_respond_to prescription, :extraction_processing?
    assert_respond_to prescription, :extraction_extracted?
    assert_respond_to prescription, :extraction_confirmed?
    assert_respond_to prescription, :extraction_failed?
  end

  test "has_one_attached scanned_document" do
    assert_respond_to Prescription.new, :scanned_document
  end

  test "accepts attached scanned_document" do
    prescription = Prescription.create!(
      user: users(:one),
      prescribed_date: Date.today
    )

    # Create a mock PDF file
    pdf_file = Tempfile.new([ "test", ".pdf" ])
    pdf_file.write("%PDF-1.4")
    pdf_file.rewind

    prescription.scanned_document.attach(
      io: pdf_file,
      filename: "prescription.pdf",
      content_type: "application/pdf"
    )

    assert prescription.scanned_document.attached?

    pdf_file.close
    pdf_file.unlink
  end

  test "can set and retrieve extracted_data as JSON" do
    prescription = Prescription.create!(
      user: users(:one),
      prescribed_date: Date.today,
      extracted_data: {
        "medications" => [
          { "drug_name" => "Aspirin", "dosage" => "100mg" }
        ],
        "doctor_name" => "Dr. Smith"
      }
    )

    prescription.reload
    assert_equal "Dr. Smith", prescription.extracted_data["doctor_name"]
    assert_equal "Aspirin", prescription.extracted_data["medications"][0]["drug_name"]
  end

  test "extraction_status transitions work correctly" do
    prescription = Prescription.create!(
      user: users(:one),
      prescribed_date: Date.today
    )

    assert prescription.extraction_manual?

    prescription.extraction_pending!
    assert prescription.extraction_pending?

    prescription.extraction_processing!
    assert prescription.extraction_processing?

    prescription.extraction_extracted!
    assert prescription.extraction_extracted?

    prescription.extraction_confirmed!
    assert prescription.extraction_confirmed?
  end

  test "extraction_status can be set to failed" do
    prescription = Prescription.create!(
      user: users(:one),
      prescribed_date: Date.today
    )

    prescription.extraction_processing!
    prescription.extraction_failed!
    assert prescription.extraction_failed?
  end
end
