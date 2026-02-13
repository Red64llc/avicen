class Prescription < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :medications, dependent: :destroy
  has_one_attached :scanned_document

  # Enums
  # Extraction status for document scanning workflow
  # - manual: Created without scanning (default)
  # - pending: Document uploaded, extraction not started
  # - processing: Extraction in progress
  # - extracted: Extraction complete, awaiting review
  # - confirmed: User confirmed extracted data
  # - failed: Extraction failed
  enum :extraction_status, {
    manual: 0,
    pending: 1,
    processing: 2,
    extracted: 3,
    confirmed: 4,
    failed: 5
  }, prefix: :extraction

  # Validations
  validates :prescribed_date, presence: true

  # Scopes
  scope :ordered, -> { order(prescribed_date: :desc) }
end

