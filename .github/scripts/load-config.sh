#!/bin/bash

# Configuration Loader Script
# 
# This script provides functions to load configuration values from the
# auto-rebase-config.yml file. It can be sourced by other scripts to
# access configuration values.
#
# USAGE:
#   source .github/scripts/load-config.sh
#   get_config "filters.required_labels[]"
#   get_config_bool "advanced.wait_for_ci" "true"
#   get_config_int "limits.min_interval_hours" "1"

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-.github/auto-rebase-config.yml}"

# Function to check if config file exists and is enabled
is_config_enabled() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 0  # No config file means use defaults (enabled)
    fi
    
    if ! command -v yq &> /dev/null; then
        return 0  # No yq means use defaults (enabled)
    fi
    
    local enabled=$(yq eval '.enabled' "$CONFIG_FILE" 2>/dev/null || echo "true")
    if [[ "$enabled" == "true" ]]; then
        return 0
    fi
    return 1
}

# Function to get a configuration value
# Usage: get_config "path.to.value" "default_value"
get_config() {
    local config_path=$1
    local default_value=${2:-""}
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default_value"
        return
    fi
    
    if ! command -v yq &> /dev/null; then
        echo "$default_value"
        return
    fi
    
    local value=$(yq eval ".$config_path" "$CONFIG_FILE" 2>/dev/null || echo "null")
    if [[ "$value" == "null" ]] || [[ -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

# Function to get a boolean configuration value
# Usage: get_config_bool "path.to.bool" "true"
get_config_bool() {
    local config_path=$1
    local default_value=${2:-"true"}
    
    local value=$(get_config "$config_path" "$default_value")
    
    # Normalize to true/false
    if [[ "$value" == "true" ]] || [[ "$value" == "1" ]] || [[ "$value" == "yes" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to get an integer configuration value
# Usage: get_config_int "path.to.int" "1"
get_config_int() {
    local config_path=$1
    local default_value=${2:-"0"}
    
    local value=$(get_config "$config_path" "$default_value")
    
    # Validate it's a number
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

# Function to get an array configuration value
# Usage: get_config_array "path.to.array[]"
get_config_array() {
    local config_path=$1
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return
    fi
    
    if ! command -v yq &> /dev/null; then
        return
    fi
    
    yq eval ".$config_path" "$CONFIG_FILE" 2>/dev/null || true
}

# Function to display current configuration (for debugging)
display_config() {
    echo "📋 Auto-Rebase Configuration"
    echo "=============================="
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "⚠️  No configuration file found at: $CONFIG_FILE"
        echo "Using default configuration"
        return
    fi
    
    if ! command -v yq &> /dev/null; then
        echo "⚠️  yq not found, cannot parse configuration"
        echo "Using default configuration"
        return
    fi
    
    echo "Configuration file: $CONFIG_FILE"
    echo ""
    
    echo "Enabled: $(get_config_bool 'enabled' 'true')"
    echo ""
    
    echo "Triggers:"
    echo "  - on_push: $(get_config_bool 'triggers.on_push' 'true')"
    echo "  - on_comment: $(get_config_bool 'triggers.on_comment' 'true')"
    echo "  - on_schedule: $(get_config_bool 'triggers.on_schedule' 'true')"
    echo ""
    
    echo "Filters:"
    echo "  - required_labels:"
    get_config_array 'filters.required_labels[]' | sed 's/^/      - /'
    echo "  - allowed_authors:"
    get_config_array 'filters.allowed_authors[]' | sed 's/^/      - /'
    echo "  - exclude_labels:"
    get_config_array 'filters.exclude_labels[]' | sed 's/^/      - /'
    echo ""
    
    echo "Limits:"
    echo "  - min_interval_hours: $(get_config_int 'limits.min_interval_hours' '1')"
    echo "  - max_retries: $(get_config_int 'limits.max_retries' '3')"
    echo "  - retry_base_delay: $(get_config_int 'limits.retry_base_delay' '60')"
    echo ""
    
    echo "Notifications:"
    echo "  - comment_on_start: $(get_config_bool 'notifications.comment_on_start' 'true')"
    echo "  - comment_on_success: $(get_config_bool 'notifications.comment_on_success' 'true')"
    echo "  - comment_on_failure: $(get_config_bool 'notifications.comment_on_failure' 'true')"
    echo "  - comment_on_skip: $(get_config_bool 'notifications.comment_on_skip' 'false')"
    echo ""
    
    echo "Conflict Handling:"
    echo "  - conflict_label: $(get_config 'conflict_handling.conflict_label' 'rebase-conflict')"
    echo "  - auto_remove_conflict_label: $(get_config_bool 'conflict_handling.auto_remove_conflict_label' 'true')"
    echo ""
    
    echo "Advanced:"
    echo "  - wait_for_ci: $(get_config_bool 'advanced.wait_for_ci' 'true')"
    echo "  - skip_if_up_to_date: $(get_config_bool 'advanced.skip_if_up_to_date' 'true')"
    echo "  - use_force_with_lease: $(get_config_bool 'advanced.use_force_with_lease' 'true')"
    echo "  - fetch_depth: $(get_config_int 'advanced.fetch_depth' '0')"
    echo ""
    echo "=============================="
}

# Export functions if script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f is_config_enabled
    export -f get_config
    export -f get_config_bool
    export -f get_config_int
    export -f get_config_array
    export -f display_config
fi
