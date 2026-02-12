require "test_helper"

class OutOfRangeCalculatorTest < ActiveSupport::TestCase
  test "returns true when value is below ref_min" do
    result = OutOfRangeCalculator.call(value: 65, ref_min: 70, ref_max: 100)
    assert_equal true, result
  end

  test "returns true when value is above ref_max" do
    result = OutOfRangeCalculator.call(value: 110, ref_min: 70, ref_max: 100)
    assert_equal true, result
  end

  test "returns false when value is within range" do
    result = OutOfRangeCalculator.call(value: 85, ref_min: 70, ref_max: 100)
    assert_equal false, result
  end

  test "returns false when value equals ref_min" do
    result = OutOfRangeCalculator.call(value: 70, ref_min: 70, ref_max: 100)
    assert_equal false, result
  end

  test "returns false when value equals ref_max" do
    result = OutOfRangeCalculator.call(value: 100, ref_min: 70, ref_max: 100)
    assert_equal false, result
  end

  test "returns nil when ref_min is nil" do
    result = OutOfRangeCalculator.call(value: 85, ref_min: nil, ref_max: 100)
    assert_nil result
  end

  test "returns nil when ref_max is nil" do
    result = OutOfRangeCalculator.call(value: 85, ref_min: 70, ref_max: nil)
    assert_nil result
  end

  test "returns nil when both ref_min and ref_max are nil" do
    result = OutOfRangeCalculator.call(value: 85, ref_min: nil, ref_max: nil)
    assert_nil result
  end

  test "handles decimal values correctly" do
    result = OutOfRangeCalculator.call(value: 4.5, ref_min: 4.0, ref_max: 6.0)
    assert_equal false, result
  end

  test "handles negative values correctly" do
    result = OutOfRangeCalculator.call(value: -5, ref_min: -10, ref_max: 0)
    assert_equal false, result
  end

  test "returns true for negative value below negative range" do
    result = OutOfRangeCalculator.call(value: -15, ref_min: -10, ref_max: 0)
    assert_equal true, result
  end
end
