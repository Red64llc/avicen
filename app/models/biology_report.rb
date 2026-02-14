class BiologyReport < ApplicationRecord
  # Includes
  include Turbo::Broadcastable

  # Associations
  belongs_to :user
  has_many :test_results, dependent: :destroy
  # Task 12.3: Configure dependent purge for scanned documents (Requirement 9.6)
  has_one_attached :document, dependent: :purge_later

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
  validates :test_date, presence: true
  validates :user_id, presence: true
  validates_with DocumentValidator

  # Scopes
  scope :ordered, -> { order(test_date: :desc) }
  scope :by_date_range, ->(from_date, to_date) {
    scope = all
    scope = scope.where("test_date >= ?", from_date) if from_date.present?
    scope = scope.where("test_date <= ?", to_date) if to_date.present?
    scope
  }
  scope :by_lab_name, ->(query) {
    return all if query.blank?
    sanitized_query = sanitize_sql_like(query)
    where("LOWER(lab_name) LIKE LOWER(?)", "%#{sanitized_query}%")
  }
end
