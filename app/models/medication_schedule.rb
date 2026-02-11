class MedicationSchedule < ApplicationRecord
  # Associations
  belongs_to :medication
  has_many :medication_logs, dependent: :destroy

  # Serialization
  serialize :days_of_week, coder: JSON

  # Validations
  validates :time_of_day, presence: true
  validates :days_of_week, presence: true
  validate :at_least_one_day_selected

  # Scopes
  scope :for_day, ->(wday) {
    where("EXISTS (SELECT 1 FROM json_each(medication_schedules.days_of_week) WHERE json_each.value = ?)", wday)
  }
  scope :ordered_by_time, -> { order(:time_of_day) }

  private

  def at_least_one_day_selected
    if days_of_week.blank? || (days_of_week.is_a?(Array) && days_of_week.empty?)
      errors.add(:days_of_week, "must have at least one day selected")
    end
  end
end
