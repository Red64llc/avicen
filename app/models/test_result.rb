class TestResult < ApplicationRecord
  # Associations
  belongs_to :biology_report
  belongs_to :biomarker

  # Validations
  validates :biomarker_id, presence: true
  validates :value, presence: true, numericality: true
  validates :unit, presence: true

  # Callbacks
  before_save :calculate_out_of_range

  # Scopes
  scope :out_of_range, -> { where(out_of_range: true) }
  scope :in_range, -> { where(out_of_range: false) }
  scope :for_biomarker, ->(biomarker_id) { where(biomarker_id: biomarker_id) }

  private

  def calculate_out_of_range
    self.out_of_range = OutOfRangeCalculator.call(
      value: value,
      ref_min: ref_min,
      ref_max: ref_max
    )
  end
end
