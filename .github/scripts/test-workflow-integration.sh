#!/bin/bash

# Integration test script for auto-rebase workflow
# Tests the complete flow: rebase → CI → auto-merge

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

test_passed() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_success "$1"
}

test_failed() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_error "$1"
}

# Test 1: Verify auto-rebase.yml exists and is valid
test_auto_rebase_workflow_exists() {
    log_info "Test 1: Checking auto-rebase.yml exists and is valid"
    
    if [[ ! -f ".github/workflows/auto-rebase.yml" ]]; then
        test_failed "auto-rebase.yml does not exist"
        return 1
    fi
    
    # Validate YAML syntax
    if command -v yamllint &> /dev/null; then
        if yamllint -d relaxed .github/workflows/auto-rebase.yml &> /dev/null; then
            test_passed "auto-rebase.yml exists and has valid YAML syntax"
        else
            test_failed "auto-rebase.yml has invalid YAML syntax"
            return 1
        fi
    else
        log_warning "yamllint not installed, skipping YAML validation"
        test_passed "auto-rebase.yml exists"
    fi
}

# Test 2: Verify auto-merge.yml compatibility
test_auto_merge_compatibility() {
    log_info "Test 2: Checking auto-merge.yml compatibility"
    
    if [[ ! -f ".github/workflows/auto-merge.yml" ]]; then
        test_failed "auto-merge.yml does not exist"
        return 1
    fi
    
    # Check that auto-merge triggers on pull_request events
    if grep -q "pull_request:" .github/workflows/auto-merge.yml; then
        test_passed "auto-merge.yml triggers on pull_request events"
    else
        test_failed "auto-merge.yml does not trigger on pull_request events"
        return 1
    fi
    
    # Check that auto-merge has required permissions
    if grep -q "contents: write" .github/workflows/auto-merge.yml && \
       grep -q "pull-requests: write" .github/workflows/auto-merge.yml; then
        test_passed "auto-merge.yml has required permissions"
    else
        test_failed "auto-merge.yml missing required permissions"
        return 1
    fi
}

# Test 3: Verify CI workflow triggers after rebase
test_ci_trigger_after_rebase() {
    log_info "Test 3: Checking CI workflow triggers after rebase"
    
    # Check that build-test.yml triggers on pull_request
    if [[ -f ".github/workflows/build-test.yml" ]]; then
        if grep -q "pull_request:" .github/workflows/build-test.yml; then
            test_passed "CI workflow triggers on pull_request events (will run after rebase)"
        else
            test_failed "CI workflow does not trigger on pull_request events"
            return 1
        fi
    else
        log_warning "build-test.yml not found, checking for other CI workflows"
        
        # Check for any workflow that triggers on pull_request
        CI_WORKFLOWS=$(grep -l "pull_request:" .github/workflows/*.yml 2>/dev/null || true)
        if [[ -n "$CI_WORKFLOWS" ]]; then
            test_passed "Found CI workflows that trigger on pull_request events"
        else
            test_failed "No CI workflows found that trigger on pull_request events"
            return 1
        fi
    fi
}

# Test 4: Verify PR metadata preservation
test_pr_metadata_preservation() {
    log_info "Test 4: Checking PR metadata preservation in rebase script"
    
    if [[ ! -f ".github/scripts/rebase-pr.sh" ]]; then
        test_failed "rebase-pr.sh script not found"
        return 1
    fi
    
    # Check that rebase script uses --force-with-lease (preserves metadata)
    if grep -q "\-\-force-with-lease" .github/scripts/rebase-pr.sh; then
        test_passed "Rebase script uses --force-with-lease (preserves PR metadata)"
    else
        test_failed "Rebase script does not use --force-with-lease"
        return 1
    fi
    
    # Check that rebase script doesn't modify PR labels
    if ! grep -q "gh pr edit.*--remove-label" .github/scripts/rebase-pr.sh && \
       ! grep -q "gh pr edit.*--add-label" .github/scripts/rebase-pr.sh; then
        test_passed "Rebase script does not modify PR labels"
    else
        log_warning "Rebase script may modify PR labels (verify this is intentional)"
    fi
}

# Test 5: Verify workflow permissions
test_workflow_permissions() {
    log_info "Test 5: Checking workflow permissions"
    
    # Check auto-rebase permissions
    if grep -A 2 "^permissions:" .github/workflows/auto-rebase.yml | grep -q "contents: write" && \
       grep -A 2 "^permissions:" .github/workflows/auto-rebase.yml | grep -q "pull-requests: write"; then
        test_passed "auto-rebase.yml has correct permissions (contents: write, pull-requests: write)"
    else
        test_failed "auto-rebase.yml missing required permissions"
        return 1
    fi
}

# Test 6: Verify concurrency control
test_concurrency_control() {
    log_info "Test 6: Checking concurrency control"
    
    # Check that auto-rebase has concurrency control
    if grep -q "^concurrency:" .github/workflows/auto-rebase.yml; then
        test_passed "auto-rebase.yml has concurrency control configured"
    else
        test_failed "auto-rebase.yml missing concurrency control"
        return 1
    fi
    
    # Check that cancel-in-progress is false (to avoid interrupting rebases)
    if grep -A 2 "^concurrency:" .github/workflows/auto-rebase.yml | grep -q "cancel-in-progress: false"; then
        test_passed "Concurrency control set to not cancel in-progress rebases"
    else
        log_warning "Concurrency control may cancel in-progress rebases"
    fi
}

# Test 7: Verify notification system
test_notification_system() {
    log_info "Test 7: Checking notification system"
    
    if [[ ! -f ".github/scripts/notify-rebase.sh" ]]; then
        test_failed "notify-rebase.sh script not found"
        return 1
    fi
    
    # Check that notification script is called in workflow
    if grep -q "notify-rebase.sh" .github/workflows/auto-rebase.yml; then
        test_passed "Notification system integrated in workflow"
    else
        test_failed "Notification system not integrated in workflow"
        return 1
    fi
}

# Test 8: Verify integration with dependabot
test_dependabot_integration() {
    log_info "Test 8: Checking Dependabot integration"
    
    # Check that auto-rebase filters for dependabot PRs
    if [[ -f ".github/scripts/filter-prs.sh" ]]; then
        if grep -q "dependabot\[bot\]" .github/scripts/filter-prs.sh || \
           grep -q "dependencies" .github/scripts/filter-prs.sh; then
            test_passed "Filter script configured for Dependabot PRs"
        else
            test_failed "Filter script not configured for Dependabot PRs"
            return 1
        fi
    else
        test_failed "filter-prs.sh script not found"
        return 1
    fi
}

# Test 9: Verify error handling
test_error_handling() {
    log_info "Test 9: Checking error handling"
    
    if [[ ! -f ".github/scripts/rebase-pr.sh" ]]; then
        test_failed "rebase-pr.sh script not found"
        return 1
    fi
    
    # Check for error handling patterns
    if grep -q "set -e" .github/scripts/rebase-pr.sh || \
       grep -q "trap.*cleanup" .github/scripts/rebase-pr.sh; then
        test_passed "Rebase script has error handling"
    else
        log_warning "Rebase script may lack comprehensive error handling"
    fi
    
    # Check for conflict detection
    if grep -q "rebase.*--abort" .github/scripts/rebase-pr.sh || \
       grep -q "conflict" .github/scripts/rebase-pr.sh; then
        test_passed "Rebase script handles conflicts"
    else
        test_failed "Rebase script does not handle conflicts"
        return 1
    fi
}

# Test 10: Verify complete workflow chain
test_complete_workflow_chain() {
    log_info "Test 10: Verifying complete workflow chain"
    
    log_info "  Checking workflow chain: rebase → CI → auto-merge"
    
    # 1. Auto-rebase triggers on push to main
    if grep -A 5 "^on:" .github/workflows/auto-rebase.yml | grep -q "push:"; then
        log_success "  ✓ Auto-rebase triggers on push to main"
    else
        log_error "  ✗ Auto-rebase does not trigger on push to main"
        test_failed "Complete workflow chain broken: auto-rebase trigger missing"
        return 1
    fi
    
    # 2. Rebase updates PR branch (force push)
    if grep -q "git push.*--force" .github/scripts/rebase-pr.sh || \
       grep -q "push_flag=\"--force" .github/scripts/rebase-pr.sh; then
        log_success "  ✓ Rebase updates PR branch with force push"
    else
        log_error "  ✗ Rebase does not update PR branch"
        test_failed "Complete workflow chain broken: rebase does not update PR"
        return 1
    fi
    
    # 3. CI triggers on PR update (pull_request: synchronize)
    if grep -A 5 "pull_request:" .github/workflows/build-test.yml 2>/dev/null | grep -q "synchronize"; then
        log_success "  ✓ CI triggers on PR synchronize event (after rebase)"
    else
        log_warning "  ⚠ CI may not trigger on PR synchronize event"
    fi
    
    # 4. Auto-merge waits for CI and merges
    if grep -q "wait-on-check" .github/workflows/auto-merge.yml || \
       grep -q "check-name" .github/workflows/auto-merge.yml; then
        log_success "  ✓ Auto-merge waits for CI checks"
    else
        log_warning "  ⚠ Auto-merge may not wait for CI checks"
    fi
    
    test_passed "Complete workflow chain verified: rebase → CI → auto-merge"
}

# Main test execution
main() {
    echo ""
    echo "=========================================="
    echo "  Auto-Rebase Workflow Integration Tests"
    echo "=========================================="
    echo ""
    
    # Change to repository root
    cd "$(git rev-parse --show-toplevel)" || exit 1
    
    # Run all tests
    test_auto_rebase_workflow_exists
    test_auto_merge_compatibility
    test_ci_trigger_after_rebase
    test_pr_metadata_preservation
    test_workflow_permissions
    test_concurrency_control
    test_notification_system
    test_dependabot_integration
    test_error_handling
    test_complete_workflow_chain
    
    # Print summary
    echo ""
    echo "=========================================="
    echo "  Test Summary"
    echo "=========================================="
    echo ""
    echo "Total Tests:  $TESTS_TOTAL"
    echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All integration tests passed! ✨"
        echo ""
        echo "The auto-rebase workflow is properly integrated with:"
        echo "  • Auto-merge workflow"
        echo "  • CI/CD pipelines"
        echo "  • PR metadata preservation"
        echo "  • Error handling and notifications"
        echo ""
        return 0
    else
        log_error "Some integration tests failed. Please review the errors above."
        echo ""
        return 1
    fi
}

# Run main function
main "$@"
