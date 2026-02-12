#!/bin/bash
# Script to run Task 2 tests
# This script documents the proper test commands for Task 2 implementation

echo "=========================================="
echo "Task 2: Model Implementation Tests"
echo "=========================================="
echo ""

echo "Running Biomarker model tests..."
bin/rails test test/models/biomarker_test.rb
BIOMARKER_EXIT=$?

echo ""
echo "Running BiologyReport model tests..."
bin/rails test test/models/biology_report_test.rb
BIOLOGY_REPORT_EXIT=$?

echo ""
echo "Running TestResult model tests..."
bin/rails test test/models/test_result_test.rb
TEST_RESULT_EXIT=$?

echo ""
echo "Running OutOfRangeCalculator service tests..."
bin/rails test test/services/out_of_range_calculator_test.rb
SERVICE_EXIT=$?

echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
echo "Biomarker tests: $([ $BIOMARKER_EXIT -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "BiologyReport tests: $([ $BIOLOGY_REPORT_EXIT -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "TestResult tests: $([ $TEST_RESULT_EXIT -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "OutOfRangeCalculator tests: $([ $SERVICE_EXIT -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo ""

# Exit with error if any test failed
if [ $BIOMARKER_EXIT -ne 0 ] || [ $BIOLOGY_REPORT_EXIT -ne 0 ] || [ $TEST_RESULT_EXIT -ne 0 ] || [ $SERVICE_EXIT -ne 0 ]; then
    echo "Some tests failed. Please review the output above."
    exit 1
else
    echo "All Task 2 tests passed!"
    exit 0
fi
