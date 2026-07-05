#!/bin/bash

# Configuration Validation Script
# 
# This script validates the auto-rebase-config.yml file for:
# - Valid YAML syntax
# - Required fields
# - Valid value types
# - Logical consistency

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE="${CONFIG_FILE:-.github/auto-rebase-config.yml}"
ERRORS=0
WARNINGS=0

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ERRORS=$((ERRORS + 1))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_warning "Configuration file not found at: $CONFIG_FILE"
    log_info "The workflow will use default configuration values"
    exit 0
fi

log_info "Validating configuration file: $CONFIG_FILE"
echo ""

# Check if yq is available
if ! command -v yq &> /dev/null; then
    log_error "yq is not installed. Cannot validate YAML syntax."
    log_info "Install yq from: https://github.com/mikefarah/yq"
    exit 1
fi

# Validate YAML syntax
log_info "Checking YAML syntax..."
if yq eval '.' "$CONFIG_FILE" > /dev/null 2>&1; then
    log_success "YAML syntax is valid"
else
    log_error "Invalid YAML syntax in configuration file"
    exit 1
fi
echo ""

# Validate boolean fields
log_info "Validating boolean fields..."
validate_bool() {
    local path=$1
    local value=$(yq eval ".$path" "$CONFIG_FILE" 2>/dev/null || echo "null")
    
    if [[ "$value" != "null" ]] && [[ "$value" != "true" ]] && [[ "$value" != "false" ]]; then
        log_error "$path must be true or false, got: $value"
    fi
}

validate_bool "enabled"
validate_bool "triggers.on_push"
validate_bool "triggers.on_comment"
validate_bool "triggers.on_schedule"
validate_bool "notifications.comment_on_start"
validate_bool "notifications.comment_on_success"
validate_bool "notifications.comment_on_failure"
validate_bool "notifications.comment_on_skip"
validate_bool "conflict_handling.auto_remove_conflict_label"
validate_bool "advanced.wait_for_ci"
validate_bool "advanced.skip_if_up_to_date"
validate_bool "advanced.use_force_with_lease"

if [[ $ERRORS -eq 0 ]]; then
    log_success "All boolean fields are valid"
fi
echo ""

# Validate integer fields
log_info "Validating integer fields..."
validate_int() {
    local path=$1
    local min_value=${2:-0}
    local value=$(yq eval ".$path" "$CONFIG_FILE" 2>/dev/null || echo "null")
    
    if [[ "$value" != "null" ]]; then
        if ! [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            log_error "$path must be a number, got: $value"
        elif (( $(echo "$value < $min_value" | bc -l) )); then
            log_warning "$path is $value, which is less than recommended minimum: $min_value"
        fi
    fi
}

validate_int "limits.min_interval_hours" 0
validate_int "limits.max_retries" 1
validate_int "limits.retry_base_delay" 1
validate_int "advanced.fetch_depth" 0

if [[ $ERRORS -eq 0 ]]; then
    log_success "All integer fields are valid"
fi
echo ""

# Validate array fields
log_info "Validating array fields..."
validate_array() {
    local path=$1
    local value=$(yq eval ".$path" "$CONFIG_FILE" 2>/dev/null || echo "null")
    
    if [[ "$value" != "null" ]] && [[ "$value" != "[]" ]]; then
        local count=$(yq eval ".$path | length" "$CONFIG_FILE" 2>/dev/null || echo "0")
        if [[ "$count" -eq 0 ]]; then
            log_warning "$path is defined but empty"
        fi
    fi
}

validate_array "filters.required_labels"
validate_array "filters.allowed_authors"
validate_array "filters.exclude_labels"

if [[ $ERRORS -eq 0 ]]; then
    log_success "All array fields are valid"
fi
echo ""

# Validate string fields
log_info "Validating string fields..."
validate_string() {
    local path=$1
    local value=$(yq eval ".$path" "$CONFIG_FILE" 2>/dev/null || echo "null")
    
    if [[ "$value" != "null" ]] && [[ -z "$value" ]]; then
        log_warning "$path is defined but empty"
    fi
}

validate_string "conflict_handling.conflict_label"

if [[ $ERRORS -eq 0 ]]; then
    log_success "All string fields are valid"
fi
echo ""

# Logical consistency checks
log_info "Checking logical consistency..."

# Check if at least one trigger is enabled
enabled=$(yq eval '.enabled' "$CONFIG_FILE" 2>/dev/null || echo "true")
if [[ "$enabled" == "true" ]]; then
    on_push=$(yq eval '.triggers.on_push' "$CONFIG_FILE" 2>/dev/null || echo "true")
    on_comment=$(yq eval '.triggers.on_comment' "$CONFIG_FILE" 2>/dev/null || echo "true")
    on_schedule=$(yq eval '.triggers.on_schedule' "$CONFIG_FILE" 2>/dev/null || echo "true")
    
    if [[ "$on_push" != "true" ]] && [[ "$on_comment" != "true" ]] && [[ "$on_schedule" != "true" ]]; then
        log_warning "All triggers are disabled. The workflow will only run via manual workflow_dispatch."
    fi
fi

# Check if required_labels is not empty
required_labels_count=$(yq eval '.filters.required_labels | length' "$CONFIG_FILE" 2>/dev/null || echo "1")
if [[ "$required_labels_count" -eq 0 ]]; then
    log_warning "No required labels defined. All PRs (from allowed authors) will be eligible."
fi

# Check if allowed_authors is not empty
allowed_authors_count=$(yq eval '.filters.allowed_authors | length' "$CONFIG_FILE" 2>/dev/null || echo "1")
if [[ "$allowed_authors_count" -eq 0 ]]; then
    log_warning "No allowed authors defined. No PRs will be eligible for auto-rebase."
fi

# Check rate limiting
min_interval=$(yq eval '.limits.min_interval_hours' "$CONFIG_FILE" 2>/dev/null || echo "1")
if (( $(echo "$min_interval < 0.5" | bc -l) )); then
    log_warning "min_interval_hours is very low ($min_interval). This may cause excessive CI runs."
fi

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    log_success "Configuration is logically consistent"
fi
echo ""

# Summary
echo "================================"
echo "Validation Summary"
echo "================================"
if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    log_success "Configuration is valid with no errors or warnings"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    log_info "Configuration is valid with $WARNINGS warning(s)"
    exit 0
else
    log_error "Configuration has $ERRORS error(s) and $WARNINGS warning(s)"
    exit 1
fi
