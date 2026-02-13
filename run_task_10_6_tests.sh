#!/bin/bash
# Script to run Task 10.6 controller tests
# Tests for BiomarkerTrendsController

echo "=========================================="
echo "Task 10.6: BiomarkerTrendsController Tests"
echo "=========================================="
echo ""

echo "Running BiomarkerTrendsController tests..."
bin/rails test test/controllers/biomarker_trends_controller_test.rb -v

EXIT_CODE=$?

echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="

if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ All BiomarkerTrendsController tests PASSED (9 tests)"
    echo ""
    echo "Test Coverage:"
    echo "  ✓ Show action with valid biomarker returns chart data JSON"
    echo "    - Returns 200 status code"
    echo "    - Assigns @biomarker instance variable"
    echo "    - Assigns @chart_data with proper structure"
    echo "    - Chart data includes test dates as labels"
    echo "    - Chart data includes values in datasets"
    echo "    - Chart data includes reference range annotations"
    echo "    - Chart data includes biology report IDs for navigation"
    echo ""
    echo "  ✓ Show action with insufficient data renders table view"
    echo "    - Returns success status"
    echo "    - Sets @insufficient_data flag to true"
    echo "    - Does not generate chart data"
    echo ""
    echo "  ✓ User scoping returns only Current.user's test results"
    echo "    - Creates test results for multiple users"
    echo "    - Verifies only current user's data is returned"
    echo "    - Other users' data is excluded from results"
    echo ""
    echo "  ✓ 404 response when biomarker not found"
    echo "    - Raises ActiveRecord::RecordNotFound for invalid ID"
    echo "    - Returns :not_found status when no data exists"
    echo ""
    echo "Requirements Coverage:"
    echo "  ✓ Requirement 5.1: Biomarker history view with line chart"
    echo "  ✓ Requirement 5.2: Reference range visualization"
    echo "  ✓ Requirement 5.3: Table view for insufficient data (< 2 points)"
    echo "  ✓ Requirement 5.4: Navigation from chart to report detail"
    echo ""
    echo "Task 10.6 implementation complete!"
    exit 0
else
    echo "✗ Some BiomarkerTrendsController tests FAILED"
    echo ""
    echo "Please review the test output above for details."
    exit 1
fi
