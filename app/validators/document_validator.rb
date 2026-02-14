# Custom validator for Active Storage document attachments
#
# Validates that attached documents are one of the allowed file types:
# - PDF (application/pdf)
# - JPEG (image/jpeg)
# - PNG (image/png)
# - HEIC (image/heic) - Added for document scanning feature
# - HEIF (image/heif) - Added for document scanning feature
#
# Also validates file size (max 10MB) for document scanning uploads.
#
# Usage:
#   class BiologyReport < ApplicationRecord
#     validates_with DocumentValidator
#   end
#
# Requirements: 1.3, 1.8, 1.9
class DocumentValidator < ActiveModel::Validator
  ALLOWED_TYPES = %w[application/pdf image/jpeg image/png image/heic image/heif].freeze
  MAX_FILE_SIZE = 10.megabytes

  def validate(record)
    return unless record.document&.attached?

    validate_content_type(record)
    validate_file_size(record)
  end

  private

  def validate_content_type(record)
    unless ALLOWED_TYPES.include?(record.document.content_type)
      record.errors.add(:document, "must be a PDF, JPEG, PNG, HEIC, or HEIF file")
    end
  end

  def validate_file_size(record)
    if record.document.byte_size > MAX_FILE_SIZE
      record.errors.add(:document, "must be less than 10MB")
    end
  end
end
