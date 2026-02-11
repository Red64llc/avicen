class MedicationSchedule < ApplicationRecord
  # Associations
  belongs_to :medication
  has_many :medication_logs, dependent: :destroy

  # Serialization
  serialize :days_of_week, coder: JSON

  # Callbacks
  before_validation :normalize_days_of_week

  # Validations
  validates :time_of_day, presence: true
  validates :days_of_week, presence: true
  validate :at_least_one_day_selected

  # Scopes
  scope :for_day, ->(wday) {
    where("EXISTS (SELECT 1 FROM json_each(medication_schedules.days_of_week) WHERE json_each.value = ?)", wday)
  }
  scope :ordered_by_time, -> { order(:time_of_day) }

  DAY_NAMES = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

  # Returns human-readable day names for the selected days_of_week
  # @return [Array<String>] e.g. ["Mon", "Wed", "Fri"]
  def days_of_week_names
    return [] unless days_of_week.is_a?(Array)
    days_of_week.sort.map { |d| DAY_NAMES[d.to_i] }.compact
  end

  private

  # Cast string values from form checkboxes to integers and remove blanks
  def normalize_days_of_week
    if days_of_week.is_a?(Array)
      self.days_of_week = days_of_week.reject(&:blank?).map(&:to_i)
    end
  end

  def at_least_one_day_selected
    if days_of_week.blank? || (days_of_week.is_a?(Array) && days_of_week.empty?)
      errors.add(:days_of_week, "must have at least one day selected")
    end
  end
end
