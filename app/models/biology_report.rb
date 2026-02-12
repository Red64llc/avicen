class BiologyReport < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :test_results, dependent: :destroy
  has_one_attached :document

  # Validations
  validates :test_date, presence: true
  validates :user_id, presence: true
  validate :document_content_type

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

  private

  def document_content_type
    return unless document.attached?

    allowed_types = %w[application/pdf image/jpeg image/png]
    unless allowed_types.include?(document.content_type)
      errors.add(:document, "must be a PDF, JPEG, or PNG file")
    end
  end
end
