# Migration to add extraction support for document scanning feature
# Adds extraction_status (enum) and extracted_data (jsonb) columns
#
# Requirements: 5.8, 10.3
class AddExtractionSupportToPrescriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :prescriptions, :extraction_status, :integer, default: 0, null: false
    add_column :prescriptions, :extracted_data, :json

    add_index :prescriptions, :extraction_status
  end
end
