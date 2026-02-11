class Drug < ApplicationRecord
  # Associations
  has_many :medications, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true
  validates :rxcui, uniqueness: true, allow_nil: true

  # Scopes
  scope :search_by_name, ->(query) { where("name LIKE ?", "%#{query}%") }
end
