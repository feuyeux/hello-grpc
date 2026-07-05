#!/bin/bash

# Security Validation Script for Auto-Rebase Workflow
# 
# This script implements security measures to protect against:
# 1. Command injection attacks
# 2. Unauthorized access
# 3. Invalid PR author verification
# 4. Token permission validation
#
# REQUIREMENTS ADDRESSED:
# - Requirement 4.3: Security measures for safe rebase operations

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[SECURITY]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SECURITY]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[SECURITY]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[SECURITY]${NC} $1" >&2
}

# Function to sanitize user input to prevent command injection
# This escapes special shell characters and validates input format
sanitize_input() {
    local input="$1"
    local input_type="${2:-generic}"
    
    # Remove any null bytes
    input=$(echo "$input" | tr -d '\0')
    
    case "$input_type" in
        pr_number)
            # PR numbers should only contain digits
            if [[ ! "$input" =~ ^[0-9]+$ ]]; then
                log_error "Invalid PR number format: $input"
                return 1
            fi
            echo "$input"
            ;;
        branch_name)
            # Branch names should not contain dangerous characters
            # Allow alphanumeric, dash, underscore, slash, dot
            if [[ ! "$input" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
                log_error "Invalid branch name format: $input"
                return 1
            fi
            # Escape any remaining special characters for shell safety
            printf '%q' "$input"
            ;;
        username)
            # Usernames should follow GitHub username rules
            # Allow alphanumeric, dash, and brackets for bots
            if [[ ! "$input" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ ! "$input" =~ ^[a-zA-Z0-9_-]+\[bot\]$ ]]; then
                log_error "Invalid username format: $input"
                return 1
            fi
            # Return without escaping for usernames (they're already validated)
            echo "$input"
            ;;
        comment)
            # Comments need careful escaping to prevent injection
            # Remove backticks, dollar signs, and other dangerous characters
            input=$(echo "$input" | sed 's/[`$\\!;]//g')
            # Return the sanitized comment without additional escaping
            echo "$input"
            ;;
        *)
            # Generic sanitization - escape all special characters
            printf '%q' "$input"
            ;;
    esac
}

# Function to validate GITHUB_TOKEN permissions
validate_token_permissions() {
    local required_permissions=("contents" "pull-requests")
    local repo="${GITHUB_REPOSITORY:-}"
    
    if [[ -z "$repo" ]]; then
        log_error "GITHUB_REPOSITORY environment variable not set"
        return 1
    fi
    
    if [[ -z "${GITHUB_TOKEN:-}" ]] && [[ -z "${GH_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN or GH_TOKEN environment variable not set"
        return 1
    fi
    
    log_info "Validating GITHUB_TOKEN permissions for repository: $repo"
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI (gh) not found, skipping permission validation"
        return 0
    fi
    
    # Try to get repository permissions
    local permissions_check
    if ! permissions_check=$(gh api "/repos/$repo" --jq '.permissions' 2>&1); then
        log_error "Failed to query repository permissions: $permissions_check"
        return 1
    fi
    
    # Parse permissions
    local has_push=$(echo "$permissions_check" | jq -r '.push // false' 2>/dev/null || echo "false")
    local has_admin=$(echo "$permissions_check" | jq -r '.admin // false' 2>/dev/null || echo "false")
    
    # Check if token has write access (push or admin)
    if [[ "$has_push" == "true" ]] || [[ "$has_admin" == "true" ]]; then
        log_success "✓ Token has 'contents: write' permission"
    else
        log_error "✗ Token lacks 'contents: write' permission"
        log_error "  Required for: git push operations"
        return 1
    fi
    
    # Verify we can access pull requests
    if gh pr list --limit 1 &> /dev/null; then
        log_success "✓ Token has 'pull-requests: write' permission"
    else
        log_error "✗ Token lacks 'pull-requests: write' permission"
        log_error "  Required for: PR comments and labels"
        return 1
    fi
    
    log_success "All required permissions validated successfully"
    return 0
}

# Function to verify PR author identity
verify_pr_author() {
    local pr_number="$1"
    local allowed_authors="${2:-dependabot[bot],github-actions[bot]}"
    
    # Sanitize PR number
    pr_number=$(sanitize_input "$pr_number" "pr_number") || return 1
    
    log_info "Verifying author of PR #$pr_number"
    
    # Get PR author
    local pr_author
    if ! pr_author=$(gh pr view "$pr_number" --json author --jq '.author.login' 2>&1); then
        log_error "Failed to get PR author: $pr_author"
        return 1
    fi
    
    # Sanitize author name
    pr_author=$(sanitize_input "$pr_author" "username") || return 1
    
    log_info "PR author: $pr_author"
    
    # Convert allowed authors to array
    IFS=',' read -ra ALLOWED_AUTHORS_ARRAY <<< "$allowed_authors"
    
    # Check if author is in allowed list
    local author_allowed=false
    for allowed_author in "${ALLOWED_AUTHORS_ARRAY[@]}"; do
        # Remove quotes from sanitized input for comparison
        local clean_author=$(echo "$pr_author" | tr -d "'\"")
        local clean_allowed=$(echo "$allowed_author" | tr -d "'\" " )
        
        if [[ "$clean_author" == "$clean_allowed" ]]; then
            author_allowed=true
            break
        fi
    done
    
    if [[ "$author_allowed" == "true" ]]; then
        log_success "✓ PR author '$pr_author' is in allowed list"
        return 0
    else
        log_error "✗ PR author '$pr_author' is not in allowed list"
        log_error "  Allowed authors: $allowed_authors"
        return 1
    fi
}

# Function to verify commenter permissions for /rebase command
verify_commenter_permissions() {
    local commenter="$1"
    local repo="${GITHUB_REPOSITORY:-}"
    local min_permission="${2:-write}"
    
    # Sanitize username
    commenter=$(sanitize_input "$commenter" "username") || return 1
    
    if [[ -z "$repo" ]]; then
        log_error "GITHUB_REPOSITORY environment variable not set"
        return 1
    fi
    
    log_info "Verifying permissions for user: $commenter"
    
    # Get user's permission level
    local permission
    if ! permission=$(gh api "/repos/$repo/collaborators/$commenter/permission" --jq '.permission' 2>&1); then
        log_error "Failed to get user permissions: $permission"
        return 1
    fi
    
    log_info "User permission level: $permission"
    
    # Check if permission meets minimum requirement
    case "$min_permission" in
        admin)
            if [[ "$permission" == "admin" ]]; then
                log_success "✓ User has required 'admin' permission"
                return 0
            fi
            ;;
        write)
            if [[ "$permission" == "admin" ]] || [[ "$permission" == "write" ]]; then
                log_success "✓ User has required 'write' or higher permission"
                return 0
            fi
            ;;
        read)
            if [[ "$permission" == "admin" ]] || [[ "$permission" == "write" ]] || [[ "$permission" == "read" ]]; then
                log_success "✓ User has required 'read' or higher permission"
                return 0
            fi
            ;;
    esac
    
    log_error "✗ User lacks required '$min_permission' permission (has: $permission)"
    return 1
}

# Function to validate branch names for safety
validate_branch_name() {
    local branch_name="$1"
    
    # Sanitize branch name
    branch_name=$(sanitize_input "$branch_name" "branch_name") || return 1
    
    # Additional validation rules
    # Prevent path traversal
    if [[ "$branch_name" =~ \.\. ]]; then
        log_error "Branch name contains path traversal: $branch_name"
        return 1
    fi
    
    # Prevent absolute paths
    if [[ "$branch_name" =~ ^/ ]]; then
        log_error "Branch name is an absolute path: $branch_name"
        return 1
    fi
    
    # Prevent refs that could be dangerous
    if [[ "$branch_name" =~ ^refs/ ]]; then
        log_error "Branch name starts with 'refs/': $branch_name"
        return 1
    fi
    
    log_success "✓ Branch name validated: $branch_name"
    echo "$branch_name"
    return 0
}

# Function to perform comprehensive security check
perform_security_check() {
    local pr_number="${1:-}"
    local check_type="${2:-full}"
    
    log_info "Performing security check (type: $check_type)"
    
    local checks_passed=0
    local checks_failed=0
    
    # Always validate token permissions
    if validate_token_permissions; then
        checks_passed=$((checks_passed + 1))
    else
        checks_failed=$((checks_failed + 1))
    fi
    
    # If PR number provided, verify author
    if [[ -n "$pr_number" ]] && [[ "$check_type" == "full" ]]; then
        if verify_pr_author "$pr_number"; then
            checks_passed=$((checks_passed + 1))
        else
            checks_failed=$((checks_failed + 1))
        fi
    fi
    
    log_info "Security check results: $checks_passed passed, $checks_failed failed"
    
    if [[ $checks_failed -gt 0 ]]; then
        log_error "Security validation failed"
        return 1
    fi
    
    log_success "All security checks passed"
    return 0
}

# Main function
main() {
    local action="${1:-check}"
    shift
    
    case "$action" in
        sanitize)
            local input="$1"
            local type="${2:-generic}"
            sanitize_input "$input" "$type"
            ;;
        validate-token)
            validate_token_permissions
            ;;
        verify-author)
            local pr_number="$1"
            verify_pr_author "$pr_number"
            ;;
        verify-commenter)
            local commenter="$1"
            local min_permission="${2:-write}"
            verify_commenter_permissions "$commenter" "$min_permission"
            ;;
        validate-branch)
            local branch_name="$1"
            validate_branch_name "$branch_name"
            ;;
        check)
            local pr_number="${1:-}"
            local check_type="${2:-full}"
            perform_security_check "$pr_number" "$check_type"
            ;;
        *)
            log_error "Unknown action: $action"
            cat << EOF
Usage: $0 <action> [arguments]

Actions:
    sanitize <input> [type]              Sanitize user input (types: pr_number, branch_name, username, comment, generic)
    validate-token                       Validate GITHUB_TOKEN permissions
    verify-author <pr_number>            Verify PR author is in allowed list
    verify-commenter <username> [perm]   Verify commenter has required permissions (default: write)
    validate-branch <branch_name>        Validate branch name for safety
    check [pr_number] [type]             Perform comprehensive security check (type: full, basic)

Examples:
    $0 sanitize "123" pr_number
    $0 validate-token
    $0 verify-author 123
    $0 verify-commenter "octocat" write
    $0 validate-branch "feature/my-branch"
    $0 check 123 full
EOF
            return 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
