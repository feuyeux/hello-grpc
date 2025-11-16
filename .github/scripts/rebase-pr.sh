#!/bin/bash

# Auto-Rebase PR Script
# This script performs the actual rebase operation for a given PR

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/load-config.sh" ]]; then
    source "$SCRIPT_DIR/load-config.sh"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error codes
ERROR_FETCH_FAILED=10
ERROR_CHECKOUT_FAILED=11
ERROR_REBASE_CONFLICT=12
ERROR_PUSH_FAILED=13
ERROR_PERMISSION_DENIED=14
ERROR_NETWORK_TIMEOUT=15
ERROR_UNKNOWN=99

# Retry configuration (can be overridden by config file)
MAX_RETRIES=$(get_config_int 'limits.max_retries' '3' 2>/dev/null || echo '3')
INITIAL_BACKOFF=$(get_config_int 'limits.retry_base_delay' '60' 2>/dev/null || echo '60')
USE_FORCE_WITH_LEASE=$(get_config_bool 'advanced.use_force_with_lease' 'true' 2>/dev/null || echo 'true')

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $0 --pr PR_NUMBER --base BASE_BRANCH --head HEAD_BRANCH [--verbose]

Options:
    --pr PR_NUMBER          PR number to rebase (required)
    --base BASE_BRANCH      Base branch name (required)
    --head HEAD_BRANCH      Head branch name (required)
    --verbose               Enable verbose logging
    -h, --help              Show this help message

Example:
    $0 --pr 123 --base main --head dependabot/npm_and_yarn/axios-1.6.0
EOF
    exit 1
}

# Parse command line arguments
VERBOSE=false
PR_NUMBER=""
BASE_BRANCH=""
HEAD_BRANCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --pr)
            PR_NUMBER="$2"
            shift 2
            ;;
        --base)
            BASE_BRANCH="$2"
            shift 2
            ;;
        --head)
            HEAD_BRANCH="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$PR_NUMBER" ]] || [[ -z "$BASE_BRANCH" ]] || [[ -z "$HEAD_BRANCH" ]]; then
    log_error "Missing required arguments"
    usage
fi

# Source security validation functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/security-validation.sh" ]]; then
    source "$SCRIPT_DIR/security-validation.sh"
    
    # Sanitize and validate inputs
    log_debug "Validating and sanitizing inputs..."
    
    # Validate PR number
    if ! PR_NUMBER=$(sanitize_input "$PR_NUMBER" "pr_number" 2>&1); then
        log_error "Invalid PR number format: $PR_NUMBER"
        exit 1
    fi
    
    # Validate base branch
    if ! BASE_BRANCH=$(validate_branch_name "$BASE_BRANCH" 2>&1); then
        log_error "Invalid base branch name: $BASE_BRANCH"
        exit 1
    fi
    
    # Validate head branch
    if ! HEAD_BRANCH=$(validate_branch_name "$HEAD_BRANCH" 2>&1); then
        log_error "Invalid head branch name: $HEAD_BRANCH"
        exit 1
    fi
    
    log_debug "Input validation completed successfully"
else
    log_warning "Security validation script not found, skipping input sanitization"
fi

# Verbose logging
verbose_log() {
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "$1"
    fi
}

# Enhanced cleanup function to be called on error
cleanup_on_failure() {
    local pr_num=$1
    local error_type=${2:-"unknown"}
    
    log_warning "Cleaning up after rebase failure for PR #$pr_num (error type: $error_type)"
    
    # Abort any ongoing rebase
    if git status 2>/dev/null | grep -q "rebase in progress"; then
        log_debug "Aborting ongoing rebase operation"
        git rebase --abort 2>/dev/null || true
    fi
    
    # Abort any ongoing merge
    if git status 2>/dev/null | grep -q "merge in progress"; then
        log_debug "Aborting ongoing merge operation"
        git merge --abort 2>/dev/null || true
    fi
    
    # Switch back to base branch
    if [[ -n "$BASE_BRANCH" ]]; then
        log_debug "Switching back to base branch: $BASE_BRANCH"
        git checkout "$BASE_BRANCH" 2>/dev/null || git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
    fi
    
    # Delete the temporary branch
    if git branch --list | grep -q "pr-$pr_num"; then
        log_debug "Deleting temporary branch: pr-$pr_num"
        git branch -D "pr-$pr_num" 2>/dev/null || true
    fi
    
    # Clean up any leftover files
    git clean -fd 2>/dev/null || true
    
    log_debug "Cleanup completed"
}

# Detect error type from git output
detect_error_type() {
    local error_output="$1"
    
    # Check for conflict errors
    if echo "$error_output" | grep -qi "conflict\|CONFLICT"; then
        echo "conflict"
        return $ERROR_REBASE_CONFLICT
    fi
    
    # Check for permission errors
    if echo "$error_output" | grep -qi "permission denied\|403\|forbidden\|authentication failed"; then
        echo "permission"
        return $ERROR_PERMISSION_DENIED
    fi
    
    # Check for network errors
    if echo "$error_output" | grep -qi "timeout\|timed out\|connection refused\|could not resolve host\|network\|failed to connect"; then
        echo "network"
        return $ERROR_NETWORK_TIMEOUT
    fi
    
    # Check for push errors
    if echo "$error_output" | grep -qi "failed to push\|rejected\|non-fast-forward"; then
        echo "push_failed"
        return $ERROR_PUSH_FAILED
    fi
    
    echo "unknown"
    return $ERROR_UNKNOWN
}

# Retry function with exponential backoff
retry_with_backoff() {
    local max_attempts=$1
    shift
    local command=("$@")
    local attempt=1
    local backoff=$INITIAL_BACKOFF
    local output
    local exit_code
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt of $max_attempts: ${command[*]}"
        
        # Execute command and capture output
        if output=$("${command[@]}" 2>&1); then
            log_debug "Command succeeded on attempt $attempt"
            echo "$output"
            return 0
        else
            exit_code=$?
            log_warning "Command failed on attempt $attempt (exit code: $exit_code)"
            
            # Detect error type
            local error_type
            error_type=$(detect_error_type "$output")
            local error_code=$?
            
            # Don't retry on certain error types
            if [[ "$error_type" == "conflict" ]] || [[ "$error_type" == "permission" ]]; then
                log_error "Non-retryable error detected: $error_type"
                echo "$output"
                return $error_code
            fi
            
            # If this was the last attempt, fail
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "All retry attempts exhausted"
                echo "$output"
                return $exit_code
            fi
            
            # Wait before retrying (exponential backoff)
            log_info "Retrying in ${backoff}s..."
            sleep $backoff
            backoff=$((backoff * 2))
            attempt=$((attempt + 1))
        fi
    done
    
    return 1
}

# Main rebase function with comprehensive error handling
rebase_pr() {
    local pr_num=$1
    local base_branch=$2
    local head_branch=$3
    local error_type=""
    local error_message=""
    local error_code=0
    
    log_info "Starting rebase for PR #$pr_num"
    log_info "Base branch: $base_branch"
    log_info "Head branch: $head_branch"
    
    # Record start time
    local start_time=$(date +%s)
    
    # Step 1: Fetch the latest changes from origin with retry
    log_info "Fetching latest changes from origin..."
    local fetch_output
    if ! fetch_output=$(retry_with_backoff $MAX_RETRIES git fetch origin "$base_branch"); then
        error_type="fetch_failed"
        error_message="Failed to fetch base branch: $base_branch"
        error_code=$ERROR_FETCH_FAILED
        
        # Detect specific error type
        local detected_type
        detected_type=$(detect_error_type "$fetch_output")
        if [[ "$detected_type" == "network" ]]; then
            error_type="network_error"
            error_code=$ERROR_NETWORK_TIMEOUT
            error_message="Network error while fetching base branch after $MAX_RETRIES attempts"
        elif [[ "$detected_type" == "permission" ]]; then
            error_type="permission_error"
            error_code=$ERROR_PERMISSION_DENIED
            error_message="Permission denied while fetching base branch"
        fi
        
        log_error "$error_message"
        log_debug "Fetch output: $fetch_output"
        cleanup_on_failure "$pr_num" "$error_type"
        return $error_code
    fi
    log_debug "Successfully fetched base branch"
    
    # Step 2: Fetch the PR branch with retry
    log_info "Fetching PR branch..."
    local pr_fetch_output
    if ! pr_fetch_output=$(retry_with_backoff $MAX_RETRIES git fetch origin "pull/$pr_num/head:pr-$pr_num"); then
        error_type="fetch_failed"
        error_message="Failed to fetch PR #$pr_num"
        error_code=$ERROR_FETCH_FAILED
        
        # Detect specific error type
        local detected_type
        detected_type=$(detect_error_type "$pr_fetch_output")
        if [[ "$detected_type" == "network" ]]; then
            error_type="network_error"
            error_code=$ERROR_NETWORK_TIMEOUT
            error_message="Network error while fetching PR branch after $MAX_RETRIES attempts"
        elif [[ "$detected_type" == "permission" ]]; then
            error_type="permission_error"
            error_code=$ERROR_PERMISSION_DENIED
            error_message="Permission denied while fetching PR branch"
        fi
        
        log_error "$error_message"
        log_debug "PR fetch output: $pr_fetch_output"
        cleanup_on_failure "$pr_num" "$error_type"
        return $error_code
    fi
    log_debug "Successfully fetched PR branch"
    
    # Step 3: Checkout the PR branch
    log_info "Checking out PR branch..."
    local checkout_output
    if ! checkout_output=$(git checkout "pr-$pr_num" 2>&1); then
        error_type="checkout_failed"
        error_message="Failed to checkout PR branch"
        error_code=$ERROR_CHECKOUT_FAILED
        
        log_error "$error_message"
        log_debug "Checkout output: $checkout_output"
        cleanup_on_failure "$pr_num" "$error_type"
        return $error_code
    fi
    log_debug "Successfully checked out PR branch"
    
    # Step 4: Perform the rebase (no retry - conflicts are not transient)
    log_info "Rebasing onto origin/$base_branch..."
    local rebase_output
    if ! rebase_output=$(git rebase "origin/$base_branch" 2>&1); then
        error_type="rebase_conflict"
        error_code=$ERROR_REBASE_CONFLICT
        
        # Check if it's a conflict or other error
        if echo "$rebase_output" | grep -qi "conflict\|CONFLICT"; then
            error_message="Rebase failed due to merge conflicts"
            log_error "$error_message"
            log_info "Conflicts detected in the following files:"
            git diff --name-only --diff-filter=U 2>/dev/null | while read -r file; do
                log_info "  - $file"
            done
        else
            error_message="Rebase failed: $rebase_output"
            log_error "$error_message"
        fi
        
        log_debug "Rebase output: $rebase_output"
        cleanup_on_failure "$pr_num" "$error_type"
        return $error_code
    fi
    log_success "Rebase completed successfully"
    
    # Step 5: Force push with lease and retry
    log_info "Pushing rebased branch..."
    
    # Determine push strategy based on configuration
    local push_flag="--force"
    if [[ "$USE_FORCE_WITH_LEASE" == "true" ]]; then
        push_flag="--force-with-lease"
        log_debug "Using --force-with-lease for safe force push"
    else
        log_debug "Using --force for force push"
    fi
    
    local push_output
    if ! push_output=$(retry_with_backoff $MAX_RETRIES git push $push_flag origin "pr-$pr_num:$head_branch"); then
        error_type="push_failed"
        error_code=$ERROR_PUSH_FAILED
        
        # Detect specific error type
        local detected_type
        detected_type=$(detect_error_type "$push_output")
        if [[ "$detected_type" == "network" ]]; then
            error_type="network_error"
            error_code=$ERROR_NETWORK_TIMEOUT
            error_message="Network error while pushing rebased branch after $MAX_RETRIES attempts"
        elif [[ "$detected_type" == "permission" ]]; then
            error_type="permission_error"
            error_code=$ERROR_PERMISSION_DENIED
            error_message="Permission denied while pushing rebased branch. Check GITHUB_TOKEN permissions."
        else
            error_message="Failed to push rebased branch. The remote may have been updated."
        fi
        
        log_error "$error_message"
        log_debug "Push output: $push_output"
        cleanup_on_failure "$pr_num" "$error_type"
        return $error_code
    fi
    log_success "Successfully pushed rebased branch"
    
    # Step 6: Cleanup
    log_debug "Cleaning up local branches..."
    git checkout "$base_branch" 2>/dev/null || true
    git branch -D "pr-$pr_num" 2>/dev/null || true
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "Rebase completed for PR #$pr_num in ${duration}s"
    
    # Output result in JSON format for workflow consumption
    cat << EOF
{
  "pr_number": $pr_num,
  "success": true,
  "message": "Rebase completed successfully",
  "duration": $duration,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    return 0
}

# Execute rebase with comprehensive error handling
if rebase_pr "$PR_NUMBER" "$BASE_BRANCH" "$HEAD_BRANCH"; then
    exit 0
else
    exit_code=$?
    
    # Determine error type and message based on exit code
    local error_type="unknown"
    local error_message="Rebase failed"
    local user_message=""
    
    case $exit_code in
        $ERROR_FETCH_FAILED)
            error_type="fetch_failed"
            error_message="Failed to fetch branches from remote"
            user_message="Unable to fetch the latest changes. Please check network connectivity and repository access."
            ;;
        $ERROR_CHECKOUT_FAILED)
            error_type="checkout_failed"
            error_message="Failed to checkout PR branch"
            user_message="Unable to checkout the PR branch. The branch may have been deleted or renamed."
            ;;
        $ERROR_REBASE_CONFLICT)
            error_type="rebase_conflict"
            error_message="Rebase failed due to merge conflicts"
            user_message="This PR has merge conflicts that must be resolved manually. Please rebase locally and resolve conflicts."
            ;;
        $ERROR_PUSH_FAILED)
            error_type="push_failed"
            error_message="Failed to push rebased branch"
            user_message="Unable to push the rebased branch. The remote may have been updated or there may be branch protection rules."
            ;;
        $ERROR_PERMISSION_DENIED)
            error_type="permission_denied"
            error_message="Permission denied"
            user_message="Permission denied. Please check that the GITHUB_TOKEN has 'contents: write' and 'pull-requests: write' permissions."
            ;;
        $ERROR_NETWORK_TIMEOUT)
            error_type="network_timeout"
            error_message="Network timeout after multiple retry attempts"
            user_message="Network connection failed after $MAX_RETRIES retry attempts. Please try again later."
            ;;
        *)
            error_type="unknown"
            error_message="Rebase failed with unknown error"
            user_message="An unexpected error occurred during rebase. Please check the workflow logs for details."
            ;;
    esac
    
    log_error "Rebase failed for PR #$PR_NUMBER: $error_message (exit code: $exit_code)"
    
    # Output detailed error result in JSON format
    cat << EOF
{
  "pr_number": $PR_NUMBER,
  "success": false,
  "error_type": "$error_type",
  "error_code": $exit_code,
  "error_message": "$error_message",
  "user_message": "$user_message",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    exit $exit_code
fi
