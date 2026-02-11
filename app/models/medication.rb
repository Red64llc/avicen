class Medication < ApplicationRecord
  # Associations
  belongs_to :prescription
  belongs_to :drug
  has_many :medication_schedules, dependent: :destroy
  has_many :medication_logs, dependent: :destroy

  # Validations
  validates :dosage, presence: true
  validates :form, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
end
