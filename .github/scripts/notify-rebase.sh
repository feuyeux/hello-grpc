#!/bin/bash

# Notification Script for Auto-Rebase
# This script handles all notification logic for rebase operations

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/load-config.sh" ]]; then
    source "$SCRIPT_DIR/load-config.sh"
fi

# Load notification settings from config
COMMENT_ON_START=$(get_config_bool 'notifications.comment_on_start' 'true' 2>/dev/null || echo 'true')
COMMENT_ON_SUCCESS=$(get_config_bool 'notifications.comment_on_success' 'true' 2>/dev/null || echo 'true')
COMMENT_ON_FAILURE=$(get_config_bool 'notifications.comment_on_failure' 'true' 2>/dev/null || echo 'true')
COMMENT_ON_SKIP=$(get_config_bool 'notifications.comment_on_skip' 'false' 2>/dev/null || echo 'false')
AUTO_REMOVE_CONFLICT_LABEL=$(get_config_bool 'conflict_handling.auto_remove_conflict_label' 'true' 2>/dev/null || echo 'true')
CONFLICT_LABEL=$(get_config 'conflict_handling.conflict_label' 'rebase-conflict' 2>/dev/null || echo 'rebase-conflict')

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Usage information
usage() {
    cat << EOF
Usage: $0 --type TYPE --pr PR_NUMBER [OPTIONS]

Notification Types:
    start               Notify that rebase is starting
    success             Notify that rebase succeeded
    failure             Notify that rebase failed
    skip                Notify that rebase was skipped

Required Options:
    --type TYPE         Notification type (required)
    --pr PR_NUMBER      PR number (required)

Optional Options:
    --error-type TYPE   Error type for failure notifications
    --error-msg MSG     Error message for failure notifications
    --user-msg MSG      User-friendly message for failure notifications
    --skip-reason MSG   Reason for skipping rebase
    --add-conflict-label Add 'rebase-conflict' label (for conflict failures)
    -h, --help          Show this help message

Environment Variables:
    GH_TOKEN or GITHUB_TOKEN    GitHub token for API access (required)

Examples:
    # Notify rebase start
    $0 --type start --pr 123

    # Notify rebase success
    $0 --type success --pr 123

    # Notify rebase failure with conflict
    $0 --type failure --pr 123 --error-type conflict --error-msg "Merge conflicts detected" --add-conflict-label

    # Notify rebase skip
    $0 --type skip --pr 123 --skip-reason "PR is already up to date"
EOF
    exit 1
}

# Parse command line arguments
NOTIFICATION_TYPE=""
PR_NUMBER=""
ERROR_TYPE=""
ERROR_MESSAGE=""
USER_MESSAGE=""
SKIP_REASON=""
ADD_CONFLICT_LABEL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            NOTIFICATION_TYPE="$2"
            shift 2
            ;;
        --pr)
            PR_NUMBER="$2"
            shift 2
            ;;
        --error-type)
            ERROR_TYPE="$2"
            shift 2
            ;;
        --error-msg)
            ERROR_MESSAGE="$2"
            shift 2
            ;;
        --user-msg)
            USER_MESSAGE="$2"
            shift 2
            ;;
        --skip-reason)
            SKIP_REASON="$2"
            shift 2
            ;;
        --add-conflict-label)
            ADD_CONFLICT_LABEL=true
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
if [[ -z "$NOTIFICATION_TYPE" ]] || [[ -z "$PR_NUMBER" ]]; then
    log_error "Missing required arguments"
    usage
fi

# Validate notification type
case "$NOTIFICATION_TYPE" in
    start|success|failure|skip)
        ;;
    *)
        log_error "Invalid notification type: $NOTIFICATION_TYPE"
        usage
        ;;
esac

# Check for GitHub token
if [[ -z "$GH_TOKEN" ]] && [[ -z "$GITHUB_TOKEN" ]]; then
    log_error "GitHub token not found. Set GH_TOKEN or GITHUB_TOKEN environment variable."
    exit 1
fi

# Use GH_TOKEN if set, otherwise use GITHUB_TOKEN
export GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"

# Function to post a comment to the PR
post_comment() {
    local pr_num=$1
    local comment_body=$2
    
    log_info "Posting comment to PR #$pr_num"
    
    # Escape special characters for JSON
    local escaped_body
    escaped_body=$(echo "$comment_body" | jq -Rs .)
    
    # Post comment using gh CLI
    if echo "$comment_body" | gh pr comment "$pr_num" --body-file -; then
        log_success "Comment posted successfully to PR #$pr_num"
        return 0
    else
        log_error "Failed to post comment to PR #$pr_num"
        return 1
    fi
}

# Function to add a label to the PR
add_label() {
    local pr_num=$1
    local label=$2
    
    log_info "Adding label '$label' to PR #$pr_num"
    
    if gh pr edit "$pr_num" --add-label "$label"; then
        log_success "Label '$label' added to PR #$pr_num"
        return 0
    else
        log_error "Failed to add label '$label' to PR #$pr_num"
        return 1
    fi
}

# Function to remove a label from the PR
remove_label() {
    local pr_num=$1
    local label=$2
    
    log_info "Removing label '$label' from PR #$pr_num"
    
    # Check if label exists first
    if gh pr view "$pr_num" --json labels --jq ".labels[].name" | grep -q "^${label}$"; then
        if gh pr edit "$pr_num" --remove-label "$label"; then
            log_success "Label '$label' removed from PR #$pr_num"
            return 0
        else
            log_error "Failed to remove label '$label' from PR #$pr_num"
            return 1
        fi
    else
        log_info "Label '$label' not found on PR #$pr_num, skipping removal"
        return 0
    fi
}

# Generate notification comment based on type
generate_comment() {
    local type=$1
    local pr_num=$2
    
    case "$type" in
        start)
            cat << EOF
## 🔄 Auto-Rebase Started

The auto-rebase workflow has started rebasing this PR onto the latest base branch.

**Status:** In Progress  
**Started:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

---
*This is an automated message from the auto-rebase workflow.*
EOF
            ;;
        
        success)
            cat << EOF
## ✅ Auto-Rebase Successful

This PR has been successfully rebased onto the latest base branch.

**Status:** Completed  
**Finished:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

The CI checks will now run on the rebased code. Once all checks pass, this PR may be automatically merged if auto-merge is enabled.

---
*This is an automated message from the auto-rebase workflow.*
EOF
            ;;
        
        failure)
            local error_section=""
            
            # Build error details section
            if [[ -n "$ERROR_TYPE" ]]; then
                error_section="**Error Type:** \`$ERROR_TYPE\`  "
            fi
            
            if [[ -n "$ERROR_MESSAGE" ]]; then
                error_section="${error_section}
**Error Details:** $ERROR_MESSAGE  "
            fi
            
            # Generate user-friendly message based on error type
            local user_friendly_msg=""
            if [[ -n "$USER_MESSAGE" ]]; then
                user_friendly_msg="$USER_MESSAGE"
            else
                case "$ERROR_TYPE" in
                    rebase_conflict|conflict)
                        user_friendly_msg="This PR has merge conflicts that must be resolved manually. Please rebase locally and resolve the conflicts."
                        ;;
                    permission_denied|permission)
                        user_friendly_msg="Permission denied during rebase. This may be due to insufficient token permissions or branch protection rules."
                        ;;
                    network_timeout|network_error|network)
                        user_friendly_msg="Network connection failed during rebase. The workflow will automatically retry on the next trigger."
                        ;;
                    fetch_failed)
                        user_friendly_msg="Failed to fetch the latest changes from the repository. Please check repository access and try again."
                        ;;
                    push_failed)
                        user_friendly_msg="Failed to push the rebased branch. The remote may have been updated or there may be branch protection rules."
                        ;;
                    *)
                        user_friendly_msg="An unexpected error occurred during rebase. Please check the workflow logs for more details."
                        ;;
                esac
            fi
            
            # Generate action items based on error type
            local action_items=""
            case "$ERROR_TYPE" in
                rebase_conflict|conflict)
                    action_items="### 📋 Action Required

1. Checkout this PR branch locally
2. Rebase onto the base branch: \`git rebase origin/main\` (or appropriate base branch)
3. Resolve any merge conflicts
4. Force push the rebased branch: \`git push --force-with-lease\`

Alternatively, you can close and reopen this PR to trigger Dependabot to recreate it."
                    ;;
                permission_denied|permission)
                    action_items="### 📋 Action Required

Please verify that:
- The \`GITHUB_TOKEN\` has \`contents: write\` and \`pull-requests: write\` permissions
- Branch protection rules allow force pushes from GitHub Actions
- The workflow has the necessary permissions configured"
                    ;;
                network_timeout|network_error|network)
                    action_items="### 🔄 Automatic Retry

The workflow will automatically retry on the next trigger event. No manual action is required unless this error persists."
                    ;;
            esac
            
            cat << EOF
## ❌ Auto-Rebase Failed

The auto-rebase workflow encountered an error while rebasing this PR.

**Status:** Failed  
**Failed:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
$error_section

### 💡 What This Means

$user_friendly_msg

$action_items

---
*This is an automated message from the auto-rebase workflow. Check the [workflow logs](https://github.com/$GITHUB_REPOSITORY/actions) for detailed error information.*
EOF
            ;;
        
        skip)
            local reason_text="No specific reason provided."
            if [[ -n "$SKIP_REASON" ]]; then
                reason_text="$SKIP_REASON"
            fi
            
            cat << EOF
## ⏭️ Auto-Rebase Skipped

The auto-rebase workflow skipped rebasing this PR.

**Status:** Skipped  
**Time:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Reason:** $reason_text

---
*This is an automated message from the auto-rebase workflow.*
EOF
            ;;
    esac
}

# Main notification logic
notify() {
    local type=$1
    local pr_num=$2
    
    log_info "Processing $type notification for PR #$pr_num"
    
    # Check if notification is enabled for this type
    local should_notify=true
    case "$type" in
        start)
            [[ "$COMMENT_ON_START" != "true" ]] && should_notify=false
            ;;
        success)
            [[ "$COMMENT_ON_SUCCESS" != "true" ]] && should_notify=false
            ;;
        failure)
            [[ "$COMMENT_ON_FAILURE" != "true" ]] && should_notify=false
            ;;
        skip)
            [[ "$COMMENT_ON_SKIP" != "true" ]] && should_notify=false
            ;;
    esac
    
    # Post comment if enabled
    if [[ "$should_notify" == true ]]; then
        # Generate comment body
        local comment_body
        comment_body=$(generate_comment "$type" "$pr_num")
        
        # Post comment
        if ! post_comment "$pr_num" "$comment_body"; then
            log_error "Failed to post $type notification comment"
            return 1
        fi
    else
        log_info "Notification disabled for type: $type (skipping comment)"
    fi
    
    # Handle label management for failure notifications
    if [[ "$type" == "failure" ]]; then
        # Add conflict label if requested
        if [[ "$ADD_CONFLICT_LABEL" == true ]]; then
            add_label "$pr_num" "$CONFLICT_LABEL" || true
        fi
    elif [[ "$type" == "success" ]]; then
        # Remove conflict label if it exists and auto-remove is enabled
        if [[ "$AUTO_REMOVE_CONFLICT_LABEL" == "true" ]]; then
            remove_label "$pr_num" "$CONFLICT_LABEL" || true
        fi
    fi
    
    log_success "$type notification completed for PR #$pr_num"
    return 0
}

# Execute notification
if notify "$NOTIFICATION_TYPE" "$PR_NUMBER"; then
    exit 0
else
    exit 1
fi
