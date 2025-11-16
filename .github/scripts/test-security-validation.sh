#!/bin/bash

# Test script for security validation functions
# This script tests all security measures to ensure they work correctly

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the security validation script
source "$SCRIPT_DIR/security-validation.sh"

# Test result functions
test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Test 1: PR Number Sanitization
test_header "Test 1: PR Number Sanitization"

# Valid PR numbers
if result=$(sanitize_input "123" "pr_number" 2>&1) && [[ "$result" == "123" ]]; then
    test_pass "Valid PR number: 123"
else
    test_fail "Valid PR number: 123 (got: $result)"
fi

if result=$(sanitize_input "1" "pr_number" 2>&1) && [[ "$result" == "1" ]]; then
    test_pass "Valid PR number: 1"
else
    test_fail "Valid PR number: 1 (got: $result)"
fi

# Invalid PR numbers
if ! sanitize_input "abc" "pr_number" 2>&1 >/dev/null; then
    test_pass "Reject invalid PR number: abc"
else
    test_fail "Reject invalid PR number: abc"
fi

if ! sanitize_input "123; rm -rf /" "pr_number" 2>&1 >/dev/null; then
    test_pass "Reject command injection in PR number"
else
    test_fail "Reject command injection in PR number"
fi

if ! sanitize_input "../../../etc/passwd" "pr_number" 2>&1 >/dev/null; then
    test_pass "Reject path traversal in PR number"
else
    test_fail "Reject path traversal in PR number"
fi

# Test 2: Branch Name Sanitization
test_header "Test 2: Branch Name Sanitization"

# Valid branch names
if result=$(sanitize_input "main" "branch_name" 2>&1) && [[ -n "$result" ]]; then
    test_pass "Valid branch name: main"
else
    test_fail "Valid branch name: main"
fi

if result=$(sanitize_input "feature/my-feature" "branch_name" 2>&1) && [[ -n "$result" ]]; then
    test_pass "Valid branch name: feature/my-feature"
else
    test_fail "Valid branch name: feature/my-feature"
fi

if result=$(sanitize_input "dependabot/npm_and_yarn/axios-1.6.0" "branch_name" 2>&1) && [[ -n "$result" ]]; then
    test_pass "Valid branch name: dependabot/npm_and_yarn/axios-1.6.0"
else
    test_fail "Valid branch name: dependabot/npm_and_yarn/axios-1.6.0"
fi

# Invalid branch names
if ! sanitize_input "branch; rm -rf /" "branch_name" 2>&1 >/dev/null; then
    test_pass "Reject command injection in branch name"
else
    test_fail "Reject command injection in branch name"
fi

if ! sanitize_input "branch\$(whoami)" "branch_name" 2>&1 >/dev/null; then
    test_pass "Reject command substitution in branch name"
else
    test_fail "Reject command substitution in branch name"
fi

# Test 3: Branch Name Validation
test_header "Test 3: Branch Name Validation"

# Valid branch names
if validate_branch_name "main" >/dev/null 2>&1; then
    test_pass "Validate branch name: main"
else
    test_fail "Validate branch name: main"
fi

if validate_branch_name "feature/test" >/dev/null 2>&1; then
    test_pass "Validate branch name: feature/test"
else
    test_fail "Validate branch name: feature/test"
fi

# Invalid branch names
if ! validate_branch_name "../../../etc/passwd" >/dev/null 2>&1; then
    test_pass "Reject path traversal: ../../../etc/passwd"
else
    test_fail "Reject path traversal: ../../../etc/passwd"
fi

if ! validate_branch_name "/etc/passwd" >/dev/null 2>&1; then
    test_pass "Reject absolute path: /etc/passwd"
else
    test_fail "Reject absolute path: /etc/passwd"
fi

if ! validate_branch_name "refs/heads/main" >/dev/null 2>&1; then
    test_pass "Reject refs/ prefix: refs/heads/main"
else
    test_fail "Reject refs/ prefix: refs/heads/main"
fi

# Test 4: Username Sanitization
test_header "Test 4: Username Sanitization"

# Valid usernames
if result=$(sanitize_input "octocat" "username" 2>/dev/null) && [[ "$result" == "octocat" ]]; then
    test_pass "Valid username: octocat"
else
    test_fail "Valid username: octocat (got: $result)"
fi

if result=$(sanitize_input "dependabot[bot]" "username" 2>/dev/null) && [[ "$result" == "dependabot[bot]" ]]; then
    test_pass "Valid username: dependabot[bot]"
else
    test_fail "Valid username: dependabot[bot] (got: $result)"
fi

if result=$(sanitize_input "github-actions[bot]" "username" 2>/dev/null) && [[ "$result" == "github-actions[bot]" ]]; then
    test_pass "Valid username: github-actions[bot]"
else
    test_fail "Valid username: github-actions[bot] (got: $result)"
fi

# Invalid usernames
if ! sanitize_input "user; rm -rf /" "username" 2>&1 >/dev/null; then
    test_pass "Reject command injection in username"
else
    test_fail "Reject command injection in username"
fi

if ! sanitize_input "user\$(whoami)" "username" 2>&1 >/dev/null; then
    test_pass "Reject command substitution in username"
else
    test_fail "Reject command substitution in username"
fi

# Test 5: Comment Sanitization
test_header "Test 5: Comment Sanitization"

# Valid comments
if result=$(sanitize_input "/rebase" "comment" 2>&1) && [[ -n "$result" ]]; then
    test_pass "Valid comment: /rebase"
else
    test_fail "Valid comment: /rebase"
fi

# Dangerous comments (should be sanitized)
if result=$(sanitize_input "/rebase; rm -rf /" "comment" 2>&1); then
    # Check that semicolon is removed (dangerous character)
    if [[ "$result" != *";"* ]]; then
        test_pass "Sanitize dangerous comment: /rebase; rm -rf /"
    else
        test_fail "Sanitize dangerous comment: /rebase; rm -rf / (result: $result)"
    fi
else
    test_fail "Sanitize dangerous comment: /rebase; rm -rf /"
fi

if result=$(sanitize_input "/rebase \`whoami\`" "comment" 2>&1); then
    # Check that backticks are removed
    if [[ "$result" != *"\`"* ]]; then
        test_pass "Remove backticks from comment"
    else
        test_fail "Remove backticks from comment (result: $result)"
    fi
else
    test_fail "Remove backticks from comment"
fi

# Test 6: Generic Sanitization
test_header "Test 6: Generic Sanitization"

# Test that generic sanitization escapes special characters
if result=$(sanitize_input "test value" "generic" 2>&1) && [[ -n "$result" ]]; then
    test_pass "Generic sanitization: test value"
else
    test_fail "Generic sanitization: test value"
fi

# Test Summary
test_header "Test Summary"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
echo ""
echo "Total tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ All security validation tests passed!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ Some security validation tests failed${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
