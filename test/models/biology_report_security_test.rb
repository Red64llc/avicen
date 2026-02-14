# frozen_string_literal: true

require "test_helper"

# Task 12.1, 12.3: Security tests for BiologyReport model
# Requirements: 9.1, 9.5, 9.6
class BiologyReportSecurityTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess::FixtureFile
  include ActiveJob::TestHelper
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @biology_report = biology_reports(:one)
  end

  # --- Task 12.1: Secure Image Storage Tests ---
  # Requirements: 9.1, 9.5

  test "document attachment is associated with biology_report owner" do
    # Requirement 9.5: Scanned images are accessible only to owning user
    image = fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg")
    @biology_report.document.attach(image)

    assert @biology_report.document.attached?
    # The biology report belongs to @user, so the attachment is scoped
    assert_equal @user.id, @biology_report.user_id
  end

  test "document cannot be accessed through another user's biology_reports" do
    # Requirement 9.5: Images accessible only to owning user
    image = fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg")
    @biology_report.document.attach(image)

    # Verify the document belongs to @user's biology report
    @user.biology_reports.find(@biology_report.id)

    # Other user cannot access this biology report
    assert_raises(ActiveRecord::RecordNotFound) do
      @other_user.biology_reports.find(@biology_report.id)
    end
  end

  test "biology_reports are always scoped by user" do
    # Requirement 9.2, 9.5: All operations scoped to authenticated user
    user_reports = @user.biology_reports
    other_reports = @other_user.biology_reports

    assert_includes user_reports, @biology_report
    assert_not_includes other_reports, @biology_report
  end

  # --- Task 12.3: Record Deletion Cascade Tests ---
  # Requirement: 9.6

  test "document is purged when biology_report is destroyed" do
    # Requirement 9.6: Document deleted when BiologyReport record deleted
    image = fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg")
    @biology_report.document.attach(image)

    assert @biology_report.document.attached?
    blob_id = @biology_report.document.blob.id

    # Destroy the biology report - this schedules the blob for purging
    @biology_report.destroy!

    # Execute enqueued purge jobs
    perform_enqueued_jobs

    # The blob should now be purged
    assert_raises(ActiveRecord::RecordNotFound) do
      ActiveStorage::Blob.find(blob_id)
    end
  end

  test "biology_report destruction cascades to test_results" do
    # Verify existing cascade behavior for test_results
    test_result = @biology_report.test_results.create!(
      biomarker: biomarkers(:glucose),
      value: 100.0,
      unit: "mg/dL"
    )

    assert_difference "TestResult.count", -@biology_report.test_results.count do
      @biology_report.destroy!
    end
  end

  test "extracted_data is removed when biology_report is destroyed" do
    # Requirement 9.6: No orphaned extracted data remains
    @biology_report.update!(
      extraction_status: :extracted,
      extracted_data: {
        lab_name: "Test Lab",
        test_results: [ { biomarker_name: "Glucose", value: "95", confidence: 0.9 } ]
      }
    )

    @biology_report.destroy!

    assert_nil BiologyReport.find_by(id: @biology_report.id)
  end
end
