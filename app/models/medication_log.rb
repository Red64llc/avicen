class MedicationLog < ApplicationRecord
  # Associations
  belongs_to :medication
  belongs_to :medication_schedule

  # Enums
  enum :status, { taken: 0, skipped: 1 }

  # Validations
  validates :scheduled_date, presence: true
  validates :medication_schedule_id, uniqueness: { scope: :scheduled_date }

  # Scopes
  scope :for_date, ->(date) { where(scheduled_date: date) }
  scope :for_period, ->(start_date, end_date) { where(scheduled_date: start_date..end_date) }
end
