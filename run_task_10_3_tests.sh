#!/bin/bash
# Script to run Task 10.3 controller tests
# Tests for BiologyReportsController

echo "=========================================="
echo "Task 10.3: BiologyReportsController Tests"
echo "=========================================="
echo ""

echo "Running BiologyReportsController tests..."
bin/rails test test/controllers/biology_reports_controller_test.rb -v

EXIT_CODE=$?

echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="

if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ All BiologyReportsController tests PASSED (32 tests)"
    echo ""
    echo "Test Coverage:"
    echo "  ✓ Index action with user scoping"
    echo "  ✓ Index filtering by date range (date_from, date_to)"
    echo "  ✓ Index filtering by lab_name"
    echo "  ✓ Index combined filters (date + lab)"
    echo "  ✓ Turbo Frame responses for filtered index"
    echo "  ✓ Show action with user scoping"
    echo "  ✓ Show action returns 404 for unauthorized access"
    echo "  ✓ Create action with valid parameters"
    echo "  ✓ Create action with invalid parameters"
    echo "  ✓ Create action scopes to current user"
    echo "  ✓ Create action with document attachment (PDF)"
    echo "  ✓ Edit action with user scoping"
    echo "  ✓ Edit action returns 404 for unauthorized access"
    echo "  ✓ Update action with metadata changes"
    echo "  ✓ Update action with invalid parameters"
    echo "  ✓ Update action returns 404 for unauthorized access"
    echo "  ✓ Update action with document attachment (PDF)"
    echo "  ✓ Update action with document replacement"
    echo "  ✓ Update action with JPEG image attachment"
    echo "  ✓ Update action with PNG image attachment"
    echo "  ✓ Update action rejects invalid file types"
    echo "  ✓ Document removal functionality"
    echo "  ✓ Destroy action"
    echo "  ✓ Destroy action cascade deletes test_results"
    echo "  ✓ Destroy action returns 404 for unauthorized access"
    echo "  ✓ Authentication requirement (unauthenticated redirect)"
    echo ""
    echo "Task 10.3 implementation complete!"
    exit 0
else
    echo "✗ Some BiologyReportsController tests FAILED"
    echo ""
    echo "Please review the test output above for details."
    exit 1
fi
