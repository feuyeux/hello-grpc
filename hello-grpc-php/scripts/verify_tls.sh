#!/usr/bin/env bash

#############################################################################
# PHP gRPC TLS Verification Script
#
# This script verifies that the PHP gRPC server and client can communicate
# using TLS encryption. It starts both server and client in TLS mode,
# monitors their logs, and validates that all RPC calls succeed.
#
# Usage: ./verify_tls.sh [options]
#############################################################################

set -euo pipefail

#############################################################################
# Global Variables
#############################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
SERVER_PORT=9996
TIMEOUT=30
VERBOSE=false
KEEP_LOGS=false

# Process tracking
SERVER_PID=""
CLIENT_PID=""

# Log files
SERVER_LOG=""
CLIENT_LOG=""

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_TIMEOUT=124

#############################################################################
# Helper Functions
#############################################################################

# Print usage information
print_usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Verify PHP gRPC TLS communication functionality.

Options:
  --port PORT       Specify server port (default: 9996)
  --timeout SECONDS Set timeout in seconds (default: 30)
  --verbose         Enable verbose output
  --keep-logs       Keep log files after verification
  --help            Display this help message

Examples:
  $(basename "$0")                    # Run with defaults
  $(basename "$0") --port 8080        # Use custom port
  $(basename "$0") --verbose          # Show detailed output
  $(basename "$0") --keep-logs        # Preserve logs after run

Exit Codes:
  0   - Verification successful
  1   - Verification failed
  124 - Timeout occurred

EOF
}

# Print verbose message
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "[VERBOSE] $*"
    fi
}

# Print info message
log_info() {
    echo "[INFO] $*"
}

# Print error message
log_error() {
    echo "[ERROR] $*" >&2
}

# Print warning message
log_warning() {
    echo "[WARNING] $*" >&2
}

#############################################################################
# Argument Parsing
#############################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                if [[ -z "${2:-}" ]] || [[ "$2" =~ ^- ]]; then
                    log_error "Option --port requires a value"
                    exit $EXIT_ERROR
                fi
                SERVER_PORT="$2"
                shift 2
                ;;
            --timeout)
                if [[ -z "${2:-}" ]] || [[ "$2" =~ ^- ]]; then
                    log_error "Option --timeout requires a value"
                    exit $EXIT_ERROR
                fi
                TIMEOUT="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --keep-logs)
                KEEP_LOGS=true
                shift
                ;;
            --help|-h)
                print_usage
                exit $EXIT_SUCCESS
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit $EXIT_ERROR
                ;;
        esac
    done
}

#############################################################################
# Main Functions (Placeholders)
#############################################################################

# Setup environment and validate prerequisites
setup_environment() {
    log_verbose "Setting up environment..."
    
    # Set working directory to PHP project root
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project directory: $PROJECT_ROOT"
        return 1
    }
    log_verbose "Working directory: $(pwd)"
    
    # Set environment variables for TLS mode
    export GRPC_HELLO_SECURE=Y
    export GRPC_SERVER_PORT="$SERVER_PORT"
    log_verbose "Environment variables set: GRPC_HELLO_SECURE=Y, GRPC_SERVER_PORT=$SERVER_PORT"
    
    # Determine certificate base path
    # First check if docker/tls/server_certs exists (project structure)
    local project_root_parent
    project_root_parent="$(dirname "$PROJECT_ROOT")"
    local docker_tls_path="$project_root_parent/docker/tls/server_certs"
    
    if [ -d "$docker_tls_path" ]; then
        export CERT_BASE_PATH="$docker_tls_path"
        log_verbose "Using project certificate path: $CERT_BASE_PATH"
    else
        # Fall back to platform-specific paths
        case "$(uname -s)" in
            Darwin*)
                export CERT_BASE_PATH="/var/hello_grpc/server_certs"
                ;;
            Linux*)
                export CERT_BASE_PATH="/var/hello_grpc/server_certs"
                ;;
            MINGW*|MSYS*|CYGWIN*)
                export CERT_BASE_PATH="d:/garden/var/hello_grpc/server_certs"
                ;;
            *)
                export CERT_BASE_PATH="/var/hello_grpc/server_certs"
                ;;
        esac
        log_verbose "Using platform-specific certificate path: $CERT_BASE_PATH"
    fi
    
    # Create temporary log directory if it doesn't exist
    local log_dir="$PROJECT_ROOT/logs"
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" || {
            log_error "Failed to create log directory: $log_dir"
            return 1
        }
        log_verbose "Created log directory: $log_dir"
    fi
    
    # Set log file paths with timestamp
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    SERVER_LOG="$log_dir/server_tls_verification_${timestamp}.log"
    CLIENT_LOG="$log_dir/client_tls_verification_${timestamp}.log"
    
    # Create log files
    touch "$SERVER_LOG" || {
        log_error "Failed to create server log file: $SERVER_LOG"
        return 1
    }
    touch "$CLIENT_LOG" || {
        log_error "Failed to create client log file: $CLIENT_LOG"
        return 1
    }
    
    log_verbose "Log files created:"
    log_verbose "  Server log: $SERVER_LOG"
    log_verbose "  Client log: $CLIENT_LOG"
    
    return 0
}

# Check prerequisites
check_prerequisites() {
    log_verbose "Checking prerequisites..."
    
    local errors=0
    
    # Check if PHP is installed
    if ! command -v php &> /dev/null; then
        log_error "PHP is not installed or not in PATH"
        errors=$((errors + 1))
    else
        local php_version
        php_version=$(php -v | head -n 1)
        log_verbose "PHP found: $php_version"
    fi
    
    # Check if composer dependencies are installed
    if [ ! -d "$PROJECT_ROOT/vendor" ]; then
        log_error "Composer dependencies not installed. Run 'composer install' first."
        errors=$((errors + 1))
    else
        log_verbose "Composer dependencies found"
    fi
    
    # Check if gRPC extension is loaded
    if ! php -m 2>&1 | grep -v "Warning" | grep -q "^grpc$"; then
        log_warning "gRPC extension not found in PHP modules"
        log_warning "TLS verification may fail without gRPC extension"
    else
        log_verbose "gRPC extension is loaded"
    fi
    
    # Check if server and client scripts exist
    if [ ! -f "$PROJECT_ROOT/hello_server.php" ]; then
        log_error "Server script not found: $PROJECT_ROOT/hello_server.php"
        errors=$((errors + 1))
    else
        log_verbose "Server script found"
    fi
    
    if [ ! -f "$PROJECT_ROOT/hello_client.php" ]; then
        log_error "Client script not found: $PROJECT_ROOT/hello_client.php"
        errors=$((errors + 1))
    else
        log_verbose "Client script found"
    fi
    
    # Verify TLS certificate files exist
    log_verbose "Checking TLS certificate files in: $CERT_BASE_PATH"
    
    local cert_files=(
        "cert.pem"
        "private.key"
        "myssl_root.cer"
    )
    
    for cert_file in "${cert_files[@]}"; do
        local cert_path="$CERT_BASE_PATH/$cert_file"
        if [ ! -f "$cert_path" ]; then
            log_error "Certificate file not found: $cert_path"
            errors=$((errors + 1))
        elif [ ! -r "$cert_path" ]; then
            log_error "Certificate file not readable: $cert_path"
            errors=$((errors + 1))
        else
            log_verbose "Certificate file found: $cert_file"
        fi
    done
    
    # Return error if any checks failed
    if [ $errors -gt 0 ]; then
        log_error "Prerequisites check failed with $errors error(s)"
        return 1
    fi
    
    log_info "All prerequisites satisfied"
    return 0
}

# Start the gRPC server in TLS mode
start_server() {
    log_verbose "Starting server in TLS mode..."
    
    # Ensure we're in the project directory
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project directory: $PROJECT_ROOT"
        return 1
    }
    
    # Start server in background and redirect output to log file
    log_verbose "Executing: php hello_server.php > $SERVER_LOG 2>&1 &"
    php hello_server.php > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    
    # Verify the process started
    sleep 1
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        log_error "Server process failed to start (PID: $SERVER_PID)"
        return 1
    fi
    
    log_info "Server started successfully (PID: $SERVER_PID)"
    log_verbose "Server log: $SERVER_LOG"
    
    return 0
}

# Wait for server to be ready
wait_for_server() {
    log_verbose "Waiting for server to be ready..."
    
    local max_wait=10
    local wait_count=0
    local server_ready=false
    
    # Wait for server to log startup message
    while [ $wait_count -lt $max_wait ]; do
        # Check if server process is still running
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            log_error "Server process died unexpectedly"
            if [ -f "$SERVER_LOG" ]; then
                log_error "Last 10 lines of server log:"
                tail -n 10 "$SERVER_LOG" >&2
            fi
            return 1
        fi
        
        # Check if server has logged the startup message
        if [ -f "$SERVER_LOG" ]; then
            if grep -q "Starting gRPC server" "$SERVER_LOG"; then
                server_ready=true
                break
            fi
        fi
        
        log_verbose "Waiting for server startup... ($((wait_count + 1))/$max_wait)"
        sleep 1
        wait_count=$((wait_count + 1))
    done
    
    if [ "$server_ready" = false ]; then
        log_error "Server did not start within ${max_wait} seconds"
        if [ -f "$SERVER_LOG" ]; then
            log_error "Server log contents:"
            cat "$SERVER_LOG" >&2
        fi
        return 1
    fi
    
    # Additional wait to ensure server is fully ready to accept connections
    log_verbose "Server startup detected, waiting for full initialization..."
    sleep 2
    
    log_info "Server is ready"
    return 0
}

# Start the gRPC client in TLS mode
start_client() {
    log_verbose "Starting client in TLS mode..."
    
    # Ensure we're in the project directory
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project directory: $PROJECT_ROOT"
        return 1
    }
    
    # Start client in background and redirect output to log file
    # Pass single iteration to client (default behavior tests all 4 RPC types)
    log_verbose "Executing: php hello_client.php 0 PHP 1 > $CLIENT_LOG 2>&1 &"
    php hello_client.php 0 PHP 1 > "$CLIENT_LOG" 2>&1 &
    CLIENT_PID=$!
    
    # Verify the process started
    sleep 1
    if ! kill -0 "$CLIENT_PID" 2>/dev/null; then
        log_error "Client process failed to start (PID: $CLIENT_PID)"
        return 1
    fi
    
    log_info "Client started successfully (PID: $CLIENT_PID)"
    log_verbose "Client log: $CLIENT_LOG"
    
    # Wait for client to complete (it should exit on its own)
    # Client needs ~22 seconds to complete all 4 RPC types
    local max_wait=25
    local wait_count=0
    
    while kill -0 "$CLIENT_PID" 2>/dev/null && [ $wait_count -lt $max_wait ]; do
        log_verbose "Waiting for client to complete... ($((wait_count + 1))/$max_wait)"
        sleep 1
        wait_count=$((wait_count + 1))
    done
    
    # Check if client is still running
    if kill -0 "$CLIENT_PID" 2>/dev/null; then
        log_warning "Client did not complete within ${max_wait} seconds"
        return 1
    fi
    
    log_info "Client execution completed"
    return 0
}

# Stop server and client processes
stop_processes() {
    log_verbose "Stopping processes..."
    
    local stopped_count=0
    
    # Stop client process if running
    if [ -n "$CLIENT_PID" ]; then
        if kill -0 "$CLIENT_PID" 2>/dev/null; then
            log_verbose "Stopping client process (PID: $CLIENT_PID)"
            kill "$CLIENT_PID" 2>/dev/null || true
            
            # Wait for graceful shutdown
            local wait_count=0
            while kill -0 "$CLIENT_PID" 2>/dev/null && [ $wait_count -lt 5 ]; do
                sleep 1
                wait_count=$((wait_count + 1))
            done
            
            # Force kill if still running
            if kill -0 "$CLIENT_PID" 2>/dev/null; then
                log_verbose "Force killing client process"
                kill -9 "$CLIENT_PID" 2>/dev/null || true
            fi
            
            wait "$CLIENT_PID" 2>/dev/null || true
            stopped_count=$((stopped_count + 1))
            log_verbose "Client process stopped"
        else
            log_verbose "Client process already stopped"
        fi
    fi
    
    # Stop server process if running
    if [ -n "$SERVER_PID" ]; then
        if kill -0 "$SERVER_PID" 2>/dev/null; then
            log_verbose "Stopping server process (PID: $SERVER_PID)"
            kill "$SERVER_PID" 2>/dev/null || true
            
            # Wait for graceful shutdown
            local wait_count=0
            while kill -0 "$SERVER_PID" 2>/dev/null && [ $wait_count -lt 5 ]; do
                sleep 1
                wait_count=$((wait_count + 1))
            done
            
            # Force kill if still running
            if kill -0 "$SERVER_PID" 2>/dev/null; then
                log_verbose "Force killing server process"
                kill -9 "$SERVER_PID" 2>/dev/null || true
            fi
            
            wait "$SERVER_PID" 2>/dev/null || true
            stopped_count=$((stopped_count + 1))
            log_verbose "Server process stopped"
        else
            log_verbose "Server process already stopped"
        fi
    fi
    
    if [ $stopped_count -gt 0 ]; then
        log_info "Stopped $stopped_count process(es)"
    fi
    
    return 0
}

# Collect logs from server and client
collect_logs() {
    log_verbose "Collecting logs..."
    # TODO: Implementation in next task
    return 0
}

# Analyze results from logs
analyze_results() {
    log_verbose "Analyzing results..."
    # TODO: Implementation in next task
    return 0
}

# Print verification report
print_report() {
    log_verbose "Generating report..."
    # TODO: Implementation in next task
    return 0
}

# Cleanup processes and temporary files
cleanup() {
    log_verbose "Cleaning up..."
    
    # Stop all processes
    stop_processes
    
    # Remove temporary log files unless --keep-logs is specified
    if [ "$KEEP_LOGS" != true ]; then
        if [ -n "$SERVER_LOG" ] && [ -f "$SERVER_LOG" ]; then
            log_verbose "Removing server log: $SERVER_LOG"
            rm -f "$SERVER_LOG"
        fi
        if [ -n "$CLIENT_LOG" ] && [ -f "$CLIENT_LOG" ]; then
            log_verbose "Removing client log: $CLIENT_LOG"
            rm -f "$CLIENT_LOG"
        fi
    else
        log_info "Log files preserved:"
        if [ -n "$SERVER_LOG" ] && [ -f "$SERVER_LOG" ]; then
            log_info "  Server: $SERVER_LOG"
        fi
        if [ -n "$CLIENT_LOG" ] && [ -f "$CLIENT_LOG" ]; then
            log_info "  Client: $CLIENT_LOG"
        fi
    fi
}

# Handle errors
handle_error() {
    local error_msg="$1"
    local error_code="${2:-$EXIT_ERROR}"
    
    log_error "$error_msg"
    cleanup
    exit "$error_code"
}

# Handle timeout
timeout_handler() {
    log_error "Verification timed out after $TIMEOUT seconds"
    cleanup
    exit $EXIT_TIMEOUT
}

#############################################################################
# Main Function
#############################################################################

main() {
    log_info "PHP gRPC TLS Verification Script"
    log_info "================================="
    log_info ""
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Display configuration
    log_info "Configuration:"
    log_info "  Port: $SERVER_PORT"
    log_info "  Timeout: ${TIMEOUT}s"
    log_info "  Verbose: $VERBOSE"
    log_info "  Keep logs: $KEEP_LOGS"
    log_info ""
    
    # Register signal handlers
    trap cleanup EXIT
    trap cleanup INT TERM
    trap timeout_handler ALRM
    
    # Set timeout alarm
    (sleep "$TIMEOUT" && kill -ALRM $$ 2>/dev/null) &
    local timeout_pid=$!
    
    # Execute verification steps
    log_info "Starting verification process..."
    
    setup_environment || handle_error "Failed to setup environment"
    check_prerequisites || handle_error "Prerequisites check failed"
    start_server || handle_error "Failed to start server"
    wait_for_server || handle_error "Server failed to start properly"
    start_client || handle_error "Failed to start client"
    collect_logs || handle_error "Failed to collect logs"
    analyze_results || handle_error "Result analysis failed"
    
    # Cancel timeout alarm
    kill "$timeout_pid" 2>/dev/null || true
    
    # Print final report
    print_report
    
    log_info ""
    log_info "Verification completed successfully!"
    
    exit $EXIT_SUCCESS
}

#############################################################################
# Script Entry Point
#############################################################################

# Run main function with all arguments
main "$@"
