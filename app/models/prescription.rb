class Prescription < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :medications, dependent: :destroy

  # Validations
  validates :prescribed_date, presence: true

  # Scopes
  scope :ordered, -> { order(prescribed_date: :desc) }
end
