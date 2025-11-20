#!/usr/bin/env bash

# Verify proxy functionality across all supported language implementations
# This script tests each language and generates a comprehensive report

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Default values
TLS_ENABLED=false
OUTPUT_FILE=""

# Display usage information
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Verify proxy functionality across all supported language implementations.
This script tests each language and generates a comprehensive report.

Optional Arguments:
  --tls, -t                Enable TLS/secure mode for all tests
  --output, -o <file>      Write report to file (default: stdout)
  --help, -h               Display this help message

Examples:
  # Test all languages without TLS
  $0

  # Test all languages with TLS enabled
  $0 --tls

  # Test all languages and save report to file
  $0 --output proxy-report.txt

  # Test with TLS and save report
  $0 --tls --output proxy-report-tls.txt

Exit Codes:
  0 - All tests passed
  1 - Invalid parameters
  2 - One or more tests failed

EOF
  exit "$EXIT_INVALID_PARAMS"
}

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tls|-t)
        TLS_ENABLED=true
        shift
        ;;
      --output|-o)
        if [[ -z "${2:-}" ]]; then
          log "ERROR" "Missing value for --output"
          usage
        fi
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --help|-h)
        usage
        ;;
      *)
        log "ERROR" "Unknown argument: $1"
        usage
        ;;
    esac
  done
}


# Test result tracking using indexed arrays
# Format: "language:status:duration:output_file"
declare -a TEST_RESULTS=()

# Get result for a language
# Args:
#   $1 - language name
#   $2 - field (status, duration, output)
get_test_result() {
  local lang="$1"
  local field="$2"
  
  for result in "${TEST_RESULTS[@]}"; do
    local result_lang="${result%%:*}"
    if [[ "$result_lang" == "$lang" ]]; then
      case "$field" in
        status)
          echo "$result" | cut -d: -f2
          return 0
          ;;
        duration)
          echo "$result" | cut -d: -f3
          return 0
          ;;
        output)
          local output_file
          output_file=$(echo "$result" | cut -d: -f4-)
          if [[ -f "$output_file" ]]; then
            cat "$output_file"
          fi
          return 0
          ;;
      esac
    fi
  done
  
  return 1
}

# Test a single language
# Args:
#   $1 - language name
# Returns:
#   0 if test passed, non-zero if failed
test_language() {
  local lang="$1"
  local start_time
  local end_time
  local duration
  local exit_code
  local output_file
  local status
  
  log "INFO" "Starting test for $lang..."
  
  # Create temporary file for test output
  output_file=$(mktemp)
  log "INFO" "Test output will be captured to: $output_file"
  
  # Record start time
  start_time=$(date +%s)
  
  # Build test command
  local test_cmd="$SCRIPT_DIR/test-proxy.sh --language $lang"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    test_cmd="$test_cmd --tls"
  fi
  
  log "INFO" "Executing: $test_cmd"
  
  # Run test and capture output
  if eval "$test_cmd" > "$output_file" 2>&1; then
    exit_code=0
    status="PASS"
    # Record end time and calculate duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log "INFO" "$lang: ✅ PASS (${duration}s)"
  else
    exit_code=$?
    status="FAIL"
    # Record end time and calculate duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log "ERROR" "$lang: ❌ FAIL (exit code: $exit_code, duration: ${duration}s)"
    log "ERROR" "Check output file for details: $output_file"
  fi
  
  # Store result
  TEST_RESULTS+=("$lang:$status:$duration:$output_file")
  
  return $exit_code
}

# Run tests for all languages
run_all_tests() {
  local start_time
  local end_time
  local duration
  
  start_time=$(date +%s)
  
  log "INFO" "=========================================="
  log "INFO" "Starting verification of all language implementations"
  log "INFO" "=========================================="
  log "INFO" "Configuration:"
  log "INFO" "  TLS mode: $(if [[ "$TLS_ENABLED" == "true" ]]; then echo "ENABLED"; else echo "DISABLED"; fi)"
  log "INFO" "  Total languages: ${#SUPPORTED_LANGUAGES[@]}"
  log "INFO" "  Proxy-supported languages: ${#PROXY_SUPPORTED_LANGUAGES[@]}"
  log "INFO" "=========================================="
  echo ""
  
  local failed_count=0
  local skipped_count=0
  local passed_count=0
  local current_test=0
  local total_tests=${#SUPPORTED_LANGUAGES[@]}
  
  # Iterate through all supported languages
  for lang in "${SUPPORTED_LANGUAGES[@]}"; do
    ((current_test++))
    
    log "INFO" "----------------------------------------"
    log "INFO" "Test $current_test/$total_tests: $lang"
    log "INFO" "----------------------------------------"
    
    # Check if language supports proxy mode
    if ! supports_proxy "$lang"; then
      log "WARN" "Skipping $lang (proxy mode not implemented)"
      # Store skipped result
      TEST_RESULTS+=("$lang:SKIP:0:/dev/null")
      ((skipped_count++))
      echo ""
      continue
    fi
    
    if test_language "$lang"; then
      ((passed_count++))
    else
      ((failed_count++))
    fi
    echo ""  # Add blank line between tests
  done
  
  # Calculate total duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  log "INFO" "=========================================="
  log "INFO" "All tests completed"
  log "INFO" "=========================================="
  log "INFO" "Results summary:"
  log "INFO" "  Total tests: $total_tests"
  log "INFO" "  Passed: $passed_count"
  log "INFO" "  Failed: $failed_count"
  log "INFO" "  Skipped: $skipped_count"
  log "INFO" "  Total duration: ${duration}s"
  log "INFO" "=========================================="
  
  return $failed_count
}


# Generate report
# Outputs:
#   Formatted report to stdout or file
generate_report() {
  local report_content
  local timestamp
  local tls_mode
  local total_tests
  local passed_tests
  local failed_tests
  local success_rate
  
  # Calculate statistics
  total_tests=${#SUPPORTED_LANGUAGES[@]}
  passed_tests=0
  failed_tests=0
  skipped_tests=0
  
  for lang in "${SUPPORTED_LANGUAGES[@]}"; do
    local status
    status=$(get_test_result "$lang" "status")
    if [[ "$status" == "PASS" ]]; then
      ((passed_tests++))
    elif [[ "$status" == "SKIP" ]]; then
      ((skipped_tests++))
    else
      ((failed_tests++))
    fi
  done
  
  # Calculate success rate
  if [[ $total_tests -gt 0 ]]; then
    success_rate=$(awk "BEGIN {printf \"%.1f\", ($passed_tests / $total_tests) * 100}")
  else
    success_rate="0.0"
  fi
  
  # Get timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  # Get TLS mode string
  if [[ "$TLS_ENABLED" == "true" ]]; then
    tls_mode="TLS Enabled"
  else
    tls_mode="TLS Disabled"
  fi
  
  # Build report content
  report_content=$(cat << EOF
Proxy Functionality Verification Report
========================================
Date: $timestamp
Mode: $tls_mode

Results:
--------
EOF
)
  
  # Add results for each language
  for lang in "${SUPPORTED_LANGUAGES[@]}"; do
    local status
    local duration
    local symbol
    
    status=$(get_test_result "$lang" "status")
    duration=$(get_test_result "$lang" "duration")
    
    if [[ "$status" == "PASS" ]]; then
      symbol="✅"
    elif [[ "$status" == "SKIP" ]]; then
      symbol="⏭️"
    else
      symbol="❌"
    fi
    
    # Format language name with proper capitalization
    local display_name
    case "$lang" in
      nodejs)
        display_name="Node.js"
        ;;
      typescript)
        display_name="TypeScript"
        ;;
      cpp)
        display_name="C++"
        ;;
      csharp)
        display_name="C#"
        ;;
      *)
        # Capitalize first letter
        display_name="$(tr '[:lower:]' '[:upper:]' <<< "${lang:0:1}")${lang:1}"
        ;;
    esac
    
    # Add to report with aligned columns
    report_content+=$(printf "\n%-3s %-12s - %-4s (%ds)" "$symbol" "$display_name" "$status" "$duration")
  done
  
  # Add summary section
  report_content+=$(cat << EOF


Summary:
--------
Total: $total_tests
Passed: $passed_tests
Failed: $failed_tests
Skipped: $skipped_tests (proxy not implemented)
Success Rate: ${success_rate}%
EOF
)
  
  # Add failed test details if any
  if [[ $failed_tests -gt 0 ]]; then
    report_content+=$(cat << EOF


Failed Test Details:
--------------------
EOF
)
    
    for lang in "${SUPPORTED_LANGUAGES[@]}"; do
      local status
      status=$(get_test_result "$lang" "status")
      if [[ "$status" == "FAIL" ]]; then
        local output
        output=$(get_test_result "$lang" "output")
        report_content+=$(cat << EOF


Language: $lang
Output:
$output
EOF
)
      fi
    done
  fi
  
  # Output report
  if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$report_content" > "$OUTPUT_FILE"
    log "INFO" "Report written to: $OUTPUT_FILE"
  else
    echo ""
    echo "$report_content"
  fi
  
  # Clean up temporary output files
  for result in "${TEST_RESULTS[@]}"; do
    local output_file
    output_file=$(echo "$result" | cut -d: -f4-)
    if [[ -f "$output_file" ]]; then
      rm -f "$output_file"
    fi
  done
}


# Main execution
main() {
  local script_start_time
  local script_end_time
  local script_duration
  
  script_start_time=$(date +%s)
  
  log "INFO" "=========================================="
  log "INFO" "Proxy Verification Script"
  log "INFO" "=========================================="
  log "INFO" "Script started at: $(date '+%Y-%m-%d %H:%M:%S')"
  
  # Parse arguments
  log "INFO" "Parsing command line arguments..."
  parse_arguments "$@"
  log "INFO" "Arguments parsed successfully"
  
  if [[ -n "$OUTPUT_FILE" ]]; then
    log "INFO" "Report will be written to: $OUTPUT_FILE"
  else
    log "INFO" "Report will be written to: stdout"
  fi
  
  # Run all tests
  log "INFO" "Beginning test execution phase..."
  local failed_count=0
  if ! run_all_tests; then
    # Some tests failed - capture the return code
    failed_count=$?
    log "WARN" "Test execution completed with $failed_count failure(s)"
  else
    log "INFO" "Test execution completed - all tests passed!"
  fi
  
  # Generate report
  log "INFO" "Generating verification report..."
  generate_report
  log "INFO" "Report generation complete"
  
  # Calculate total script duration
  script_end_time=$(date +%s)
  script_duration=$((script_end_time - script_start_time))
  
  # Exit with appropriate code
  log "INFO" "=========================================="
  if [[ $failed_count -gt 0 ]]; then
    log "INFO" "Verification completed with failures"
    log "INFO" "Total script duration: ${script_duration}s"
    log "INFO" "Exit code: 2"
    log "INFO" "=========================================="
    exit 2
  else
    log "INFO" "Verification completed successfully"
    log "INFO" "Total script duration: ${script_duration}s"
    log "INFO" "Exit code: 0"
    log "INFO" "=========================================="
    exit "$EXIT_SUCCESS"
  fi
}

# Run main function
main "$@"
