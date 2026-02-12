# Custom validator for Active Storage document attachments
#
# Validates that attached documents are one of the allowed file types:
# - PDF (application/pdf)
# - JPEG (image/jpeg)
# - PNG (image/png)
#
# Usage:
#   class BiologyReport < ApplicationRecord
#     validates_with DocumentValidator
#   end
class DocumentValidator < ActiveModel::Validator
  ALLOWED_TYPES = %w[application/pdf image/jpeg image/png].freeze

  def validate(record)
    return unless record.document.attached?

    unless ALLOWED_TYPES.include?(record.document.content_type)
      record.errors.add(:document, "must be a PDF, JPEG, or PNG file")
    end
  end
end
