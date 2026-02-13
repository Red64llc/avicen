class Biomarker < ApplicationRecord
  # Associations
  has_many :test_results

  # Validations
  validates :name, presence: true
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :unit, presence: true
  validates :ref_min, presence: true, numericality: true
  validates :ref_max, presence: true, numericality: true

  # Scopes
  scope :search, ->(query) {
    return none if query.blank?
    sanitized_query = sanitize_sql_like(query)
    where("LOWER(name) LIKE LOWER(?) OR LOWER(code) LIKE LOWER(?)",
          "%#{sanitized_query}%", "%#{sanitized_query}%")
  }

  # Class methods
  def self.autocomplete_search(query)
    return none if query.blank?
    search(query).limit(10)
  end
end
