# frozen_string_literal: true

require "test_helper"

# Task 12.1, 12.3: Security tests for Prescription model
# Requirements: 9.1, 9.5, 9.6
class PrescriptionSecurityTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @prescription = prescriptions(:one)
  end

  # --- Task 12.1: Secure Image Storage Tests ---
  # Requirements: 9.1, 9.5

  test "scanned_document attachment is associated with prescription owner" do
    # Requirement 9.5: Scanned images are accessible only to owning user
    image = fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg")
    @prescription.scanned_document.attach(image)

    assert @prescription.scanned_document.attached?
    # The prescription belongs to @user, so the attachment is scoped
    assert_equal @user.id, @prescription.user_id
  end

  test "scanned_document cannot be accessed through another user's prescriptions" do
    # Requirement 9.5: Images accessible only to owning user
    image = fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg")
    @prescription.scanned_document.attach(image)

    # Verify the scanned document belongs to @user's prescription
    @user.prescriptions.find(@prescription.id)

    # Other user cannot access this prescription
    assert_raises(ActiveRecord::RecordNotFound) do
      @other_user.prescriptions.find(@prescription.id)
    end
  end

  test "prescriptions are always scoped by user" do
    # Requirement 9.2, 9.5: All operations scoped to authenticated user
    user_prescriptions = @user.prescriptions
    other_prescriptions = @other_user.prescriptions

    assert_includes user_prescriptions, @prescription
    assert_not_includes other_prescriptions, @prescription
  end

  # --- Task 12.3: Record Deletion Cascade Tests ---
  # Requirement: 9.6

  test "scanned_document is purged when prescription is destroyed" do
    # Requirement 9.6: Image deleted when Prescription record deleted
    image = fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg")
    @prescription.scanned_document.attach(image)

    assert @prescription.scanned_document.attached?
    blob_id = @prescription.scanned_document.blob.id

    # Destroy the prescription
    @prescription.destroy!

    # The blob should be scheduled for purging
    # In test environment, purge_later is executed inline
    assert_raises(ActiveRecord::RecordNotFound) do
      ActiveStorage::Blob.find(blob_id)
    end
  end

  test "prescription destruction cascades to medications" do
    # Verify existing cascade behavior for medications
    medication = @prescription.medications.create!(
      drug_name: "Test Drug",
      dosage: "100mg"
    )

    assert_difference "Medication.count", -@prescription.medications.count do
      @prescription.destroy!
    end
  end

  test "extracted_data is removed when prescription is destroyed" do
    # Requirement 9.6: No orphaned extracted data remains
    @prescription.update!(
      extraction_status: :extracted,
      extracted_data: {
        doctor_name: "Dr. Test",
        medications: [{ drug_name: "Test", confidence: 0.9 }]
      }
    )

    @prescription.destroy!

    assert_nil Prescription.find_by(id: @prescription.id)
  end
end
