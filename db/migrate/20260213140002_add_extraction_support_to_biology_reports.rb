# Migration to add extraction support for document scanning feature
# Adds extraction_status (enum) and extracted_data (jsonb) columns
# Note: BiologyReport already has document attachment via Active Storage
#
# Requirements: 5.8, 10.3
class AddExtractionSupportToBiologyReports < ActiveRecord::Migration[8.1]
  def change
    add_column :biology_reports, :extraction_status, :integer, default: 0, null: false
    add_column :biology_reports, :extracted_data, :json

    add_index :biology_reports, :extraction_status
  end
end
