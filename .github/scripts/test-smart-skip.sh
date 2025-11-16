#!/bin/bash

# Test script for smart skip logic in filter-prs.sh
# This script tests the various skip conditions

set -e

echo "🧪 Testing Smart Skip Logic"
echo "============================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Test 1: Verify script exists and is executable
echo "Test 1: Script existence and permissions"
if [[ -f ".github/scripts/filter-prs.sh" ]]; then
    test_pass "filter-prs.sh exists"
else
    test_fail "filter-prs.sh not found"
fi

if [[ -x ".github/scripts/filter-prs.sh" ]]; then
    test_pass "filter-prs.sh is executable"
else
    test_info "Making filter-prs.sh executable"
    chmod +x .github/scripts/filter-prs.sh
    test_pass "filter-prs.sh made executable"
fi

echo ""

# Test 2: Verify required functions exist
echo "Test 2: Required functions"
REQUIRED_FUNCTIONS=(
    "has_required_label"
    "is_allowed_author"
    "is_behind_base"
    "has_merge_conflicts"
    "is_ci_running"
    "check_frequency_limit"
    "filter_pr"
    "log_skip_reason"
    "display_skip_summary"
    "get_eligible_prs"
)

for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if grep -q "^${func}()" .github/scripts/filter-prs.sh; then
        test_pass "Function '$func' exists"
    else
        test_fail "Function '$func' not found"
    fi
done

echo ""

# Test 3: Verify configuration variables
echo "Test 3: Configuration variables"
CONFIG_VARS=(
    "REQUIRED_LABEL"
    "ALLOWED_AUTHORS"
    "MIN_REBASE_INTERVAL_HOURS"
    "CONFLICT_LABEL"
    "SKIP_LOG_FILE"
)

for var in "${CONFIG_VARS[@]}"; do
    if grep -q "^${var}=" .github/scripts/filter-prs.sh; then
        test_pass "Configuration variable '$var' defined"
    else
        test_fail "Configuration variable '$var' not found"
    fi
done

echo ""

# Test 4: Verify smart skip logic implementation
echo "Test 4: Smart skip logic checks"

# Check for CI running check
if grep -q "is_ci_running" .github/scripts/filter-prs.sh; then
    test_pass "CI running check implemented"
else
    test_fail "CI running check not found"
fi

# Check for up-to-date check
if grep -q "is_behind_base" .github/scripts/filter-prs.sh; then
    test_pass "Up-to-date check implemented"
else
    test_fail "Up-to-date check not found"
fi

# Check for frequency limit
if grep -q "check_frequency_limit" .github/scripts/filter-prs.sh; then
    test_pass "Frequency limit check implemented"
else
    test_fail "Frequency limit check not found"
fi

# Check for skip reason logging
if grep -q "log_skip_reason" .github/scripts/filter-prs.sh; then
    test_pass "Skip reason logging implemented"
else
    test_fail "Skip reason logging not found"
fi

echo ""

# Test 5: Verify GitHub Actions integration
echo "Test 5: GitHub Actions integration"

if grep -q "GITHUB_ACTIONS" .github/scripts/filter-prs.sh; then
    test_pass "GitHub Actions detection implemented"
else
    test_fail "GitHub Actions detection not found"
fi

if grep -q "::notice" .github/scripts/filter-prs.sh; then
    test_pass "GitHub Actions annotations implemented"
else
    test_fail "GitHub Actions annotations not found"
fi

echo ""

# Test 6: Verify command line argument parsing
echo "Test 6: Command line arguments"

if grep -q "\-\-pr" .github/scripts/filter-prs.sh; then
    test_pass "--pr argument supported"
else
    test_fail "--pr argument not found"
fi

if grep -q "\-\-verbose" .github/scripts/filter-prs.sh; then
    test_pass "--verbose argument supported"
else
    test_fail "--verbose argument not found"
fi

echo ""

# Test 7: Verify skip log file handling
echo "Test 7: Skip log file handling"

if grep -q "SKIP_LOG_FILE" .github/scripts/filter-prs.sh; then
    test_pass "Skip log file variable defined"
else
    test_fail "Skip log file variable not found"
fi

if grep -q "display_skip_summary" .github/scripts/filter-prs.sh; then
    test_pass "Skip summary display function exists"
else
    test_fail "Skip summary display function not found"
fi

echo ""

# Test 8: Syntax check
echo "Test 8: Shell script syntax"
if bash -n .github/scripts/filter-prs.sh 2>/dev/null; then
    test_pass "Script has valid bash syntax"
else
    test_fail "Script has syntax errors"
fi

echo ""

# Summary
echo "============================"
echo "Test Summary"
echo "============================"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo "Total: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
