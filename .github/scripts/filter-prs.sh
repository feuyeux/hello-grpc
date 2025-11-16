#!/bin/bash

# PR Filtering Script for Auto-Rebase Workflow
# 
# This script implements smart skip logic to filter PRs based on various criteria:
# 
# FILTERING CRITERIA:
# 1. Open status - Only open PRs are considered
# 2. Required labels - Must have 'dependencies' label
# 3. Allowed authors - Must be dependabot[bot] or github-actions[bot]
# 4. Merge conflicts - PRs with conflicts are skipped
# 5. Up-to-date check - PRs already up-to-date with base branch are skipped
# 6. CI status check - PRs with running CI checks are skipped to avoid interference
# 7. Frequency limit - Rate limiting to prevent excessive rebases (1 hour minimum)
#
# SKIP REASON LOGGING:
# - All skip decisions are logged with detailed reasons
# - Logs are written to $SKIP_LOG_FILE (default: /tmp/auto-rebase-skip-log.txt)
# - GitHub Actions annotations are added for visibility in workflow runs
# - Summary statistics are displayed in verbose mode
#
# REQUIREMENTS ADDRESSED:
# - Requirement 3.1: Check if PR is already up-to-date
# - Requirement 3.3: Implement frequency limit (1 hour)
# - Requirement 3.4: Wait for CI checks to complete before rebasing
#
# USAGE:
#   ./filter-prs.sh [--pr PR_NUMBER] [--verbose]
#
# OPTIONS:
#   --pr PR_NUMBER    Filter a specific PR (optional)
#   --verbose         Enable detailed logging output
#
# OUTPUT:
#   Prints eligible PR numbers (one per line) to stdout
#   Logs and messages are written to stderr

set -e

# Default configuration (can be overridden by config file)
DEFAULT_REQUIRED_LABELS=("dependencies")
DEFAULT_ALLOWED_AUTHORS=("dependabot[bot]" "github-actions[bot]")
DEFAULT_EXCLUDE_LABELS=("no-rebase" "wip" "do-not-merge" "hold")
DEFAULT_MIN_REBASE_INTERVAL_HOURS=1
DEFAULT_CONFLICT_LABEL="rebase-conflict"
DEFAULT_WAIT_FOR_CI=true
DEFAULT_SKIP_IF_UP_TO_DATE=true

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-.github/auto-rebase-config.yml}"

# Function to load configuration from YAML file
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        # Config file doesn't exist, use defaults
        REQUIRED_LABELS=("${DEFAULT_REQUIRED_LABELS[@]}")
        ALLOWED_AUTHORS=("${DEFAULT_ALLOWED_AUTHORS[@]}")
        EXCLUDE_LABELS=("${DEFAULT_EXCLUDE_LABELS[@]}")
        MIN_REBASE_INTERVAL_HOURS=$DEFAULT_MIN_REBASE_INTERVAL_HOURS
        CONFLICT_LABEL=$DEFAULT_CONFLICT_LABEL
        WAIT_FOR_CI=$DEFAULT_WAIT_FOR_CI
        SKIP_IF_UP_TO_DATE=$DEFAULT_SKIP_IF_UP_TO_DATE
        return
    fi
    
    # Check if yq is available for YAML parsing
    if ! command -v yq &> /dev/null; then
        echo "⚠️  Warning: yq not found, using default configuration" >&2
        REQUIRED_LABELS=("${DEFAULT_REQUIRED_LABELS[@]}")
        ALLOWED_AUTHORS=("${DEFAULT_ALLOWED_AUTHORS[@]}")
        EXCLUDE_LABELS=("${DEFAULT_EXCLUDE_LABELS[@]}")
        MIN_REBASE_INTERVAL_HOURS=$DEFAULT_MIN_REBASE_INTERVAL_HOURS
        CONFLICT_LABEL=$DEFAULT_CONFLICT_LABEL
        WAIT_FOR_CI=$DEFAULT_WAIT_FOR_CI
        SKIP_IF_UP_TO_DATE=$DEFAULT_SKIP_IF_UP_TO_DATE
        return
    fi
    
    # Load required labels
    local required_labels_yaml=$(yq eval '.filters.required_labels[]' "$CONFIG_FILE" 2>/dev/null || echo "")
    if [[ -n "$required_labels_yaml" ]]; then
        mapfile -t REQUIRED_LABELS <<< "$required_labels_yaml"
    else
        REQUIRED_LABELS=("${DEFAULT_REQUIRED_LABELS[@]}")
    fi
    
    # Load allowed authors
    local allowed_authors_yaml=$(yq eval '.filters.allowed_authors[]' "$CONFIG_FILE" 2>/dev/null || echo "")
    if [[ -n "$allowed_authors_yaml" ]]; then
        mapfile -t ALLOWED_AUTHORS <<< "$allowed_authors_yaml"
    else
        ALLOWED_AUTHORS=("${DEFAULT_ALLOWED_AUTHORS[@]}")
    fi
    
    # Load exclude labels
    local exclude_labels_yaml=$(yq eval '.filters.exclude_labels[]' "$CONFIG_FILE" 2>/dev/null || echo "")
    if [[ -n "$exclude_labels_yaml" ]]; then
        mapfile -t EXCLUDE_LABELS <<< "$exclude_labels_yaml"
    else
        EXCLUDE_LABELS=("${DEFAULT_EXCLUDE_LABELS[@]}")
    fi
    
    # Load min interval hours
    local min_interval=$(yq eval '.limits.min_interval_hours' "$CONFIG_FILE" 2>/dev/null || echo "null")
    if [[ "$min_interval" != "null" ]] && [[ -n "$min_interval" ]]; then
        MIN_REBASE_INTERVAL_HOURS=$min_interval
    else
        MIN_REBASE_INTERVAL_HOURS=$DEFAULT_MIN_REBASE_INTERVAL_HOURS
    fi
    
    # Load conflict label
    local conflict_label=$(yq eval '.conflict_handling.conflict_label' "$CONFIG_FILE" 2>/dev/null || echo "null")
    if [[ "$conflict_label" != "null" ]] && [[ -n "$conflict_label" ]]; then
        CONFLICT_LABEL=$conflict_label
    else
        CONFLICT_LABEL=$DEFAULT_CONFLICT_LABEL
    fi
    
    # Load wait for CI setting
    local wait_for_ci=$(yq eval '.advanced.wait_for_ci' "$CONFIG_FILE" 2>/dev/null || echo "null")
    if [[ "$wait_for_ci" != "null" ]] && [[ -n "$wait_for_ci" ]]; then
        WAIT_FOR_CI=$wait_for_ci
    else
        WAIT_FOR_CI=$DEFAULT_WAIT_FOR_CI
    fi
    
    # Load skip if up-to-date setting
    local skip_if_up_to_date=$(yq eval '.advanced.skip_if_up_to_date' "$CONFIG_FILE" 2>/dev/null || echo "null")
    if [[ "$skip_if_up_to_date" != "null" ]] && [[ -n "$skip_if_up_to_date" ]]; then
        SKIP_IF_UP_TO_DATE=$skip_if_up_to_date
    else
        SKIP_IF_UP_TO_DATE=$DEFAULT_SKIP_IF_UP_TO_DATE
    fi
}

# Load configuration
load_config

# Log file for skip reasons
SKIP_LOG_FILE="${SKIP_LOG_FILE:-/tmp/auto-rebase-skip-log.txt}"

# Function to log skip reasons
log_skip_reason() {
    local pr_number=$1
    local reason=$2
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create log entry
    local log_entry="[$timestamp] PR #$pr_number: $reason"
    
    # Append to log file
    echo "$log_entry" >> "$SKIP_LOG_FILE"
    
    # Also log to GitHub Actions if running in CI
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        if [[ "$reason" == "eligible" ]]; then
            echo "::notice title=PR #$pr_number::Eligible for rebase"
        else
            echo "::notice title=PR #$pr_number Skipped::$reason"
        fi
    fi
}

# Function to check if PR has at least one required label
has_required_label() {
    local pr_number=$1
    local labels=$(gh pr view "$pr_number" --json labels --jq '.labels[].name')
    
    # Check if PR has at least one of the required labels
    for required_label in "${REQUIRED_LABELS[@]}"; do
        if echo "$labels" | grep -q "^${required_label}$"; then
            return 0
        fi
    done
    return 1
}

# Function to check if PR has any exclude labels
has_exclude_label() {
    local pr_number=$1
    local labels=$(gh pr view "$pr_number" --json labels --jq '.labels[].name')
    
    # Check if PR has any of the exclude labels
    for exclude_label in "${EXCLUDE_LABELS[@]}"; do
        if echo "$labels" | grep -q "^${exclude_label}$"; then
            return 0
        fi
    done
    return 1
}

# Function to check if PR author is allowed
is_allowed_author() {
    local pr_number=$1
    local author=$(gh pr view "$pr_number" --json author --jq '.author.login')
    
    for allowed_author in "${ALLOWED_AUTHORS[@]}"; do
        if [[ "$author" == "$allowed_author" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check if PR is behind base branch
is_behind_base() {
    local pr_number=$1
    local base_branch=$(gh pr view "$pr_number" --json baseRefName --jq '.baseRefName')
    local head_branch=$(gh pr view "$pr_number" --json headRefName --jq '.headRefName')
    
    # Fetch latest changes
    git fetch origin "$base_branch" "$head_branch" --quiet 2>/dev/null || true
    
    # Check if head is behind base
    local behind_count=$(git rev-list --count "origin/$head_branch..origin/$base_branch" 2>/dev/null || echo "0")
    
    if [[ "$behind_count" -gt 0 ]]; then
        return 0
    fi
    return 1
}

# Function to check if PR has merge conflicts
has_merge_conflicts() {
    local pr_number=$1
    
    # Check if PR has conflict label
    local labels=$(gh pr view "$pr_number" --json labels --jq '.labels[].name')
    if echo "$labels" | grep -q "^${CONFLICT_LABEL}$"; then
        return 0
    fi
    
    # Check mergeable state from GitHub API
    local mergeable=$(gh pr view "$pr_number" --json mergeable --jq '.mergeable')
    if [[ "$mergeable" == "CONFLICTING" ]]; then
        return 0
    fi
    
    return 1
}

# Function to check if CI is running
is_ci_running() {
    local pr_number=$1
    
    # Get the status checks for the PR
    local status_checks=$(gh pr view "$pr_number" --json statusCheckRollup --jq '.statusCheckRollup[]' 2>/dev/null || echo "")
    
    if [[ -z "$status_checks" ]]; then
        # No status checks found, allow rebase
        return 1
    fi
    
    # Check if any status check is in pending or in_progress state
    local pending_count=$(echo "$status_checks" | jq -r 'select(.status == "PENDING" or .status == "IN_PROGRESS" or .conclusion == null) | .name' 2>/dev/null | wc -l)
    
    if [[ "$pending_count" -gt 0 ]]; then
        return 0
    fi
    
    return 1
}

# Function to check frequency limit
check_frequency_limit() {
    local pr_number=$1
    
    # Get the last rebase comment timestamp
    local last_rebase_comment=$(gh pr view "$pr_number" --json comments --jq '
        .comments[] | 
        select(.body | contains("🔄 Auto-rebase completed successfully") or contains("🔄 Starting auto-rebase")) | 
        .createdAt' | tail -1)
    
    if [[ -z "$last_rebase_comment" ]]; then
        # No previous rebase found, allow rebase
        return 0
    fi
    
    # Calculate time difference in hours
    local last_rebase_epoch=$(date -d "$last_rebase_comment" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_rebase_comment" +%s 2>/dev/null || echo "0")
    local current_epoch=$(date +%s)
    local hours_diff=$(( (current_epoch - last_rebase_epoch) / 3600 ))
    
    if [[ "$hours_diff" -ge "$MIN_REBASE_INTERVAL_HOURS" ]]; then
        return 0
    fi
    
    return 1
}

# Function to filter a single PR with detailed skip reason logging
filter_pr() {
    local pr_number=$1
    local verbose=${2:-false}
    local skip_reason=""
    
    if [[ "$verbose" == "true" ]]; then
        echo "🔍 Checking PR #$pr_number..." >&2
    fi
    
    # Check if PR has any exclude labels
    if has_exclude_label "$pr_number"; then
        local pr_labels=$(gh pr view "$pr_number" --json labels --jq '.labels[].name' | tr '\n' ', ' | sed 's/,$//')
        skip_reason="PR has exclude label (labels: $pr_labels, exclude: ${EXCLUDE_LABELS[*]})"
        [[ "$verbose" == "true" ]] && echo "  ⏭️  Skipping: $skip_reason" >&2
        log_skip_reason "$pr_number" "$skip_reason"
        return 1
    fi
    
    # Check if PR has required label
    if ! has_required_label "$pr_number"; then
        local pr_labels=$(gh pr view "$pr_number" --json labels --jq '.labels[].name' | tr '\n' ', ' | sed 's/,$//')
        skip_reason="Missing required label (labels: $pr_labels, required: ${REQUIRED_LABELS[*]})"
        [[ "$verbose" == "true" ]] && echo "  ⏭️  Skipping: $skip_reason" >&2
        log_skip_reason "$pr_number" "$skip_reason"
        return 1
    fi
    
    # Check if PR author is allowed
    if ! is_allowed_author "$pr_number"; then
        local author=$(gh pr view "$pr_number" --json author --jq '.author.login')
        skip_reason="Author '$author' not in allowed list (${ALLOWED_AUTHORS[*]})"
        [[ "$verbose" == "true" ]] && echo "  ⏭️  Skipping: $skip_reason" >&2
        log_skip_reason "$pr_number" "$skip_reason"
        return 1
    fi
    
    # Check if PR has merge conflicts
    if has_merge_conflicts "$pr_number"; then
        skip_reason="PR has merge conflicts - manual resolution required"
        [[ "$verbose" == "true" ]] && echo "  ⚠️  Skipping: $skip_reason" >&2
        log_skip_reason "$pr_number" "$skip_reason"
        return 1
    fi
    
    # Check if PR is behind base branch (already up-to-date check)
    if [[ "$SKIP_IF_UP_TO_DATE" == "true" ]]; then
        if ! is_behind_base "$pr_number"; then
            skip_reason="PR is already up-to-date with base branch"
            [[ "$verbose" == "true" ]] && echo "  ✅ Skipping: $skip_reason" >&2
            log_skip_reason "$pr_number" "$skip_reason"
            return 1
        fi
    fi
    
    # Check if CI is currently running
    if [[ "$WAIT_FOR_CI" == "true" ]]; then
        if is_ci_running "$pr_number"; then
            skip_reason="CI checks are currently running - waiting for completion"
            [[ "$verbose" == "true" ]] && echo "  ⏳ Skipping: $skip_reason" >&2
            log_skip_reason "$pr_number" "$skip_reason"
            return 1
        fi
    fi
    
    # Check frequency limit (rate limiting)
    if ! check_frequency_limit "$pr_number"; then
        local last_rebase_comment=$(gh pr view "$pr_number" --json comments --jq '
            .comments[] | 
            select(.body | contains("🔄 Auto-rebase completed successfully") or contains("🔄 Starting auto-rebase")) | 
            .createdAt' | tail -1)
        
        if [[ -n "$last_rebase_comment" ]]; then
            local last_rebase_epoch=$(date -d "$last_rebase_comment" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_rebase_comment" +%s 2>/dev/null || echo "0")
            local current_epoch=$(date +%s)
            local hours_diff=$(( (current_epoch - last_rebase_epoch) / 3600 ))
            local minutes_diff=$(( (current_epoch - last_rebase_epoch) / 60 ))
            
            skip_reason="Rate limit: Last rebase was ${hours_diff}h ${minutes_diff}m ago (minimum: ${MIN_REBASE_INTERVAL_HOURS}h)"
        else
            skip_reason="Rate limit check failed"
        fi
        
        [[ "$verbose" == "true" ]] && echo "  ⏱️  Skipping: $skip_reason" >&2
        log_skip_reason "$pr_number" "$skip_reason"
        return 1
    fi
    
    if [[ "$verbose" == "true" ]]; then
        echo "  ✅ PR #$pr_number is eligible for rebase" >&2
    fi
    
    log_skip_reason "$pr_number" "eligible"
    return 0
}

# Function to display skip log summary
display_skip_summary() {
    local verbose=${1:-false}
    
    if [[ ! -f "$SKIP_LOG_FILE" ]]; then
        return
    fi
    
    if [[ "$verbose" == "true" ]]; then
        echo "" >&2
        echo "📊 Skip Reason Summary:" >&2
        echo "======================" >&2
        
        # Count skip reasons
        local total_checked=$(grep -c "PR #" "$SKIP_LOG_FILE" 2>/dev/null || echo "0")
        local eligible_count=$(grep -c "eligible" "$SKIP_LOG_FILE" 2>/dev/null || echo "0")
        local skipped_count=$((total_checked - eligible_count))
        
        echo "Total PRs checked: $total_checked" >&2
        echo "Eligible for rebase: $eligible_count" >&2
        echo "Skipped: $skipped_count" >&2
        
        if [[ $skipped_count -gt 0 ]]; then
            echo "" >&2
            echo "Skip reasons breakdown:" >&2
            
            # Extract and count unique skip reasons
            grep -v "eligible" "$SKIP_LOG_FILE" 2>/dev/null | sed 's/.*: //' | sort | uniq -c | sort -rn | while read -r count reason; do
                echo "  - $reason: $count" >&2
            done
        fi
        
        echo "======================" >&2
    fi
}

# Main function to get all eligible PRs
get_eligible_prs() {
    local specific_pr=$1
    local verbose=${2:-false}
    
    # Initialize skip log
    > "$SKIP_LOG_FILE"
    
    # If specific PR is provided, only check that one
    if [[ -n "$specific_pr" ]]; then
        if filter_pr "$specific_pr" "$verbose"; then
            echo "$specific_pr"
        fi
        display_skip_summary "$verbose"
        return
    fi
    
    # Get all open PRs
    local all_prs=$(gh pr list --state open --json number --jq '.[].number')
    
    if [[ -z "$all_prs" ]]; then
        [[ "$verbose" == "true" ]] && echo "ℹ️  No open PRs found" >&2
        display_skip_summary "$verbose"
        return
    fi
    
    local eligible_prs=()
    
    # Filter each PR
    for pr_number in $all_prs; do
        if filter_pr "$pr_number" "$verbose"; then
            eligible_prs+=("$pr_number")
        fi
    done
    
    # Output eligible PRs
    if [[ ${#eligible_prs[@]} -gt 0 ]]; then
        printf "%s\n" "${eligible_prs[@]}"
    else
        [[ "$verbose" == "true" ]] && echo "ℹ️  No eligible PRs found for rebase" >&2
    fi
    
    # Display summary
    display_skip_summary "$verbose"
}

# Parse command line arguments
SPECIFIC_PR=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --pr)
            SPECIFIC_PR="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--pr PR_NUMBER] [--verbose]" >&2
            exit 1
            ;;
    esac
done

# Source security validation functions for input sanitization
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/security-validation.sh" ]]; then
    source "$SCRIPT_DIR/security-validation.sh"
    
    # Sanitize PR number if provided
    if [[ -n "$SPECIFIC_PR" ]]; then
        if ! SPECIFIC_PR=$(sanitize_input "$SPECIFIC_PR" "pr_number" 2>&1); then
            echo "❌ Invalid PR number format: $SPECIFIC_PR" >&2
            exit 1
        fi
    fi
fi

# Run the main function
get_eligible_prs "$SPECIFIC_PR" "$VERBOSE"
