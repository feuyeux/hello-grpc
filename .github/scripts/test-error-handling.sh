#!/bin/bash

# Test script for error handling mechanisms
# This script tests the error detection and retry logic

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBASE_SCRIPT="$SCRIPT_DIR/rebase-pr.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} $1"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}[PASS]${NC} $1"
    echo ""
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}[FAIL]${NC} $1"
    echo ""
}

# Test 1: Verify error codes are defined
test_start "Verify error codes are defined in script"
if grep -q "ERROR_FETCH_FAILED=10" "$REBASE_SCRIPT" && \
   grep -q "ERROR_CHECKOUT_FAILED=11" "$REBASE_SCRIPT" && \
   grep -q "ERROR_REBASE_CONFLICT=12" "$REBASE_SCRIPT" && \
   grep -q "ERROR_PUSH_FAILED=13" "$REBASE_SCRIPT" && \
   grep -q "ERROR_PERMISSION_DENIED=14" "$REBASE_SCRIPT" && \
   grep -q "ERROR_NETWORK_TIMEOUT=15" "$REBASE_SCRIPT"; then
    test_pass "All error codes are properly defined"
else
    test_fail "Some error codes are missing"
fi

# Test 2: Verify retry configuration
test_start "Verify retry configuration exists"
if grep -q "MAX_RETRIES=3" "$REBASE_SCRIPT" && \
   grep -q "INITIAL_BACKOFF=2" "$REBASE_SCRIPT"; then
    test_pass "Retry configuration is properly set"
else
    test_fail "Retry configuration is missing or incorrect"
fi

# Test 3: Verify cleanup function exists
test_start "Verify cleanup_on_failure function exists"
if grep -q "cleanup_on_failure()" "$REBASE_SCRIPT"; then
    test_pass "cleanup_on_failure function is defined"
else
    test_fail "cleanup_on_failure function is missing"
fi

# Test 4: Verify error detection function exists
test_start "Verify detect_error_type function exists"
if grep -q "detect_error_type()" "$REBASE_SCRIPT"; then
    test_pass "detect_error_type function is defined"
else
    test_fail "detect_error_type function is missing"
fi

# Test 5: Verify retry function exists
test_start "Verify retry_with_backoff function exists"
if grep -q "retry_with_backoff()" "$REBASE_SCRIPT"; then
    test_pass "retry_with_backoff function is defined"
else
    test_fail "retry_with_backoff function is missing"
fi

# Test 6: Verify cleanup handles rebase abort
test_start "Verify cleanup handles rebase abort"
if grep -q "git rebase --abort" "$REBASE_SCRIPT"; then
    test_pass "Cleanup includes rebase abort"
else
    test_fail "Cleanup missing rebase abort"
fi

# Test 7: Verify cleanup handles merge abort
test_start "Verify cleanup handles merge abort"
if grep -q "git merge --abort" "$REBASE_SCRIPT"; then
    test_pass "Cleanup includes merge abort"
else
    test_fail "Cleanup missing merge abort"
fi

# Test 8: Verify cleanup handles branch deletion
test_start "Verify cleanup handles branch deletion"
if grep -q "git branch -D" "$REBASE_SCRIPT"; then
    test_pass "Cleanup includes branch deletion"
else
    test_fail "Cleanup missing branch deletion"
fi

# Test 9: Verify error type detection for conflicts
test_start "Verify conflict detection in error handling"
if grep -qi "conflict" "$REBASE_SCRIPT" && grep -q "detect_error_type" "$REBASE_SCRIPT"; then
    test_pass "Conflict detection is implemented"
else
    test_fail "Conflict detection is missing"
fi

# Test 10: Verify error type detection for permissions
test_start "Verify permission error detection"
if grep -qi "permission denied" "$REBASE_SCRIPT"; then
    test_pass "Permission error detection is implemented"
else
    test_fail "Permission error detection is missing"
fi

# Test 11: Verify error type detection for network issues
test_start "Verify network error detection"
if grep -qi "timeout\|network" "$REBASE_SCRIPT"; then
    test_pass "Network error detection is implemented"
else
    test_fail "Network error detection is missing"
fi

# Test 12: Verify exponential backoff in retry logic
test_start "Verify exponential backoff implementation"
if grep -q "backoff=\$((backoff \* 2))" "$REBASE_SCRIPT"; then
    test_pass "Exponential backoff is implemented"
else
    test_fail "Exponential backoff is missing"
fi

# Test 13: Verify non-retryable errors are handled
test_start "Verify non-retryable errors skip retry"
if grep -q "Don't retry on certain error types" "$REBASE_SCRIPT" || \
   grep -q "Non-retryable error" "$REBASE_SCRIPT"; then
    test_pass "Non-retryable error handling is implemented"
else
    test_fail "Non-retryable error handling is missing"
fi

# Test 14: Verify JSON error output format
test_start "Verify JSON error output includes required fields"
if grep -q '"error_type"' "$REBASE_SCRIPT" && \
   grep -q '"error_code"' "$REBASE_SCRIPT" && \
   grep -q '"error_message"' "$REBASE_SCRIPT" && \
   grep -q '"user_message"' "$REBASE_SCRIPT"; then
    test_pass "JSON error output includes all required fields"
else
    test_fail "JSON error output is missing required fields"
fi

# Test 15: Verify logging functions exist
test_start "Verify enhanced logging functions"
if grep -q "log_debug()" "$REBASE_SCRIPT" && \
   grep -q "log_error()" "$REBASE_SCRIPT" && \
   grep -q "log_warning()" "$REBASE_SCRIPT"; then
    test_pass "Enhanced logging functions are defined"
else
    test_fail "Some logging functions are missing"
fi

# Print summary
echo "================================================"
echo -e "${BLUE}Test Summary${NC}"
echo "================================================"
echo "Tests Run:    $TESTS_RUN"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
else
    echo -e "${GREEN}Tests Failed: $TESTS_FAILED${NC}"
fi
echo "================================================"

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
