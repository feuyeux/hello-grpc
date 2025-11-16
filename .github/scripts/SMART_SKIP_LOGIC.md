# Smart Skip Logic Implementation

## Overview

The smart skip logic is implemented in `filter-prs.sh` to intelligently determine which PRs should be rebased and which should be skipped. This prevents unnecessary rebase operations, saves CI resources, and avoids conflicts with running workflows.

## Requirements Addressed

This implementation addresses the following requirements from the spec:

- **Requirement 3.1**: Check if PR is already up-to-date
- **Requirement 3.3**: Implement frequency limit (1 hour minimum between rebases)
- **Requirement 3.4**: Wait for CI checks to complete before rebasing

## Skip Conditions

The filter script checks PRs against the following conditions in order:

### 1. Required Label Check
- **Condition**: PR must have the `dependencies` label
- **Skip Reason**: "Missing 'dependencies' label"
- **Purpose**: Only rebase dependency update PRs

### 2. Author Check
- **Condition**: PR author must be `dependabot[bot]` or `github-actions[bot]`
- **Skip Reason**: "Author 'X' not in allowed list"
- **Purpose**: Only rebase automated dependency PRs

### 3. Merge Conflicts Check
- **Condition**: PR must not have merge conflicts
- **Skip Reason**: "PR has merge conflicts - manual resolution required"
- **Purpose**: Avoid attempting to rebase PRs that require manual conflict resolution
- **Detection Methods**:
  - Checks for `rebase-conflict` label
  - Checks GitHub API mergeable state

### 4. Up-to-Date Check ✨ (NEW)
- **Condition**: PR must be behind the base branch
- **Skip Reason**: "PR is already up-to-date with base branch"
- **Purpose**: Avoid unnecessary rebase operations when PR is current
- **Implementation**: Uses `git rev-list --count` to check if head is behind base

### 5. CI Running Check ✨ (NEW)
- **Condition**: No CI checks should be in pending or in-progress state
- **Skip Reason**: "CI checks are currently running - waiting for completion"
- **Purpose**: Avoid interfering with running CI workflows
- **Implementation**: Queries GitHub API for status check rollup
- **Detection**: Checks for `PENDING`, `IN_PROGRESS`, or `null` conclusion states

### 6. Frequency Limit Check ✨ (ENHANCED)
- **Condition**: At least 1 hour must have passed since last rebase
- **Skip Reason**: "Rate limit: Last rebase was Xh Ym ago (minimum: 1h)"
- **Purpose**: Prevent excessive rebase operations
- **Implementation**: 
  - Searches PR comments for rebase notifications
  - Calculates time difference from last rebase
  - Displays both hours and minutes in skip reason

## Skip Reason Logging

All skip decisions are logged with detailed information:

### Log File
- **Location**: `/tmp/auto-rebase-skip-log.txt` (configurable via `SKIP_LOG_FILE` env var)
- **Format**: `[TIMESTAMP] PR #NUMBER: REASON`
- **Example**: `[2024-11-16T10:30:00Z] PR #123: CI checks are currently running - waiting for completion`

### GitHub Actions Integration
When running in GitHub Actions, skip reasons are also logged as workflow annotations:
- **Eligible PRs**: `::notice title=PR #123::Eligible for rebase`
- **Skipped PRs**: `::notice title=PR #123 Skipped::REASON`

### Summary Statistics
In verbose mode, a summary is displayed at the end:
```
📊 Skip Reason Summary:
======================
Total PRs checked: 10
Eligible for rebase: 2
Skipped: 8

Skip reasons breakdown:
  - CI checks are currently running - waiting for completion: 3
  - PR is already up-to-date with base branch: 2
  - Rate limit: Last rebase was 0h 45m ago (minimum: 1h): 2
  - Missing 'dependencies' label: 1
======================
```

## Usage

### Basic Usage
```bash
# Filter all open PRs
./filter-prs.sh

# Filter a specific PR
./filter-prs.sh --pr 123

# Enable verbose logging
./filter-prs.sh --verbose
```

### Environment Variables
- `SKIP_LOG_FILE`: Path to skip reason log file (default: `/tmp/auto-rebase-skip-log.txt`)
- `GITHUB_ACTIONS`: Automatically detected, enables GitHub Actions annotations

### Output
- **stdout**: Eligible PR numbers (one per line)
- **stderr**: Log messages, skip reasons, and summaries

## Testing

Run the test suite to verify the implementation:

```bash
bash .github/scripts/test-smart-skip.sh
```

The test suite verifies:
- Script existence and permissions
- All required functions are present
- Configuration variables are defined
- Smart skip logic checks are implemented
- GitHub Actions integration
- Command line argument parsing
- Skip log file handling
- Shell script syntax

## Implementation Details

### CI Status Check
The `is_ci_running()` function queries the GitHub API for the PR's status check rollup:

```bash
is_ci_running() {
    local pr_number=$1
    local status_checks=$(gh pr view "$pr_number" --json statusCheckRollup --jq '.statusCheckRollup[]')
    
    # Check for pending or in-progress checks
    local pending_count=$(echo "$status_checks" | jq -r 'select(.status == "PENDING" or .status == "IN_PROGRESS" or .conclusion == null) | .name' | wc -l)
    
    if [[ "$pending_count" -gt 0 ]]; then
        return 0  # CI is running
    fi
    return 1  # CI is not running
}
```

### Up-to-Date Check
The `is_behind_base()` function uses git to check if the PR branch is behind:

```bash
is_behind_base() {
    local pr_number=$1
    local base_branch=$(gh pr view "$pr_number" --json baseRefName --jq '.baseRefName')
    local head_branch=$(gh pr view "$pr_number" --json headRefName --jq '.headRefName')
    
    git fetch origin "$base_branch" "$head_branch" --quiet
    local behind_count=$(git rev-list --count "origin/$head_branch..origin/$base_branch")
    
    if [[ "$behind_count" -gt 0 ]]; then
        return 0  # PR is behind
    fi
    return 1  # PR is up-to-date
}
```

### Frequency Limit Check
The `check_frequency_limit()` function searches PR comments for rebase notifications:

```bash
check_frequency_limit() {
    local pr_number=$1
    local last_rebase_comment=$(gh pr view "$pr_number" --json comments --jq '
        .comments[] | 
        select(.body | contains("🔄 Auto-rebase completed successfully") or contains("🔄 Starting auto-rebase")) | 
        .createdAt' | tail -1)
    
    # Calculate time difference and check against minimum interval
    # ...
}
```

## Benefits

1. **Resource Efficiency**: Avoids unnecessary rebase operations
2. **CI Stability**: Prevents interference with running workflows
3. **Transparency**: Detailed logging of all skip decisions
4. **Debugging**: Easy to understand why a PR was skipped
5. **Monitoring**: Summary statistics for workflow analysis
6. **Rate Limiting**: Prevents excessive API calls and rebase operations

## Future Enhancements

Potential improvements for the smart skip logic:

1. **Configurable CI Wait Time**: Allow configuration of how long to wait for CI
2. **Smart Scheduling**: Rebase during off-peak hours
3. **Priority Queue**: Rebase critical PRs first
4. **Conflict Prediction**: Analyze changes to predict potential conflicts
5. **Metrics Dashboard**: Visualize skip reasons over time
