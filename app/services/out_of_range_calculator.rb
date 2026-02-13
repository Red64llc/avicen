class OutOfRangeCalculator
  # Calculate out-of-range flag for a test result
  #
  # @param value [Numeric] Test result value
  # @param ref_min [Numeric, nil] Minimum reference value
  # @param ref_max [Numeric, nil] Maximum reference value
  # @return [Boolean, nil] True if out of range, false if in range, nil if ranges not provided
  def self.call(value:, ref_min:, ref_max:)
    return nil if ref_min.nil? || ref_max.nil?

    value < ref_min || value > ref_max
  end
end
