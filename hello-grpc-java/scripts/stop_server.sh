#!/usr/bin/env bash
# Script to stop gRPC server running on port 9996 or by process name

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Default configuration
PORT="9996"
FORCE=false
VERBOSE=false

# Show help
show_help() {
    cat << EOF
gRPC Server Stop Script

Usage: $0 [options]

Options:
  --port=PORT       Port number to check (default: 9996)
  --force, -f       Force kill processes (SIGKILL)
  --verbose, -v     Verbose output
  --help, -h        Show this help message

Examples:
  $0                        # Stop server on port 9996
  $0 --port=9997           # Stop server on port 9997
  $0 --force               # Force kill server processes
EOF
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port=*)
                PORT="${1#*=}"
                shift
                ;;
            --force|-f)
                FORCE=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help to see available options"
                exit 1
                ;;
        esac
    done
}

# Find and kill processes by port
kill_by_port() {
    local port=$1
    local signal=${2:-TERM}
    
    log_info "Searching for processes using port $port..."
    
    # Use lsof to find processes
    local pids=$(lsof -ti :$port 2>/dev/null || true)
    
    if [ -z "$pids" ]; then
        log_info "No processes found using port $port"
        return 0
    fi
    
    log_info "Found processes: $pids"
    
    for pid in $pids; do
        # Get process info
        if [ "$VERBOSE" = true ]; then
            local proc_info=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
            log_info "Killing process $pid ($proc_info) with SIG$signal"
        else
            log_info "Killing process $pid with SIG$signal"
        fi
        
        # Kill the process
        if kill -s $signal $pid 2>/dev/null; then
            log_success "Sent SIG$signal to process $pid"
            
            # Wait for process to terminate (if SIGTERM)
            if [ "$signal" = "TERM" ]; then
                local count=0
                while kill -0 $pid 2>/dev/null && [ $count -lt 10 ]; do
                    sleep 0.5
                    count=$((count + 1))
                done
                
                # Force kill if still running
                if kill -0 $pid 2>/dev/null; then
                    log_warning "Process $pid didn't terminate gracefully, force killing..."
                    kill -9 $pid 2>/dev/null || true
                fi
            fi
        else
            log_warning "Failed to kill process $pid (may already be dead)"
        fi
    done
}

# Find and kill processes by name
kill_by_name() {
    local name=$1
    local signal=${2:-TERM}
    
    log_info "Searching for processes matching '$name'..."
    
    # Use pkill to find and kill processes
    if [ "$VERBOSE" = true ]; then
        pgrep -fl "$name" || true
    fi
    
    if pgrep -f "$name" > /dev/null 2>&1; then
        log_info "Killing processes matching '$name' with SIG$signal..."
        if [ "$signal" = "KILL" ]; then
            pkill -9 -f "$name" 2>/dev/null || true
        else
            pkill -f "$name" 2>/dev/null || true
        fi
        sleep 1
        
        # Check if any processes remain
        if pgrep -f "$name" > /dev/null 2>&1; then
            log_warning "Some processes still running, checking..."
            if [ "$VERBOSE" = true ]; then
                pgrep -fl "$name" || true
            fi
        else
            log_success "All processes matching '$name' terminated"
        fi
    else
        log_info "No processes found matching '$name'"
    fi
}

# Clean up PID file
cleanup_pid_file() {
    local pid_file="$SCRIPT_DIR/server.pid"
    
    if [ -f "$pid_file" ]; then
        local saved_pid=$(cat "$pid_file")
        log_info "Found PID file with PID: $saved_pid"
        
        if kill -0 $saved_pid 2>/dev/null; then
            log_info "Process $saved_pid is still running, killing..."
            if [ "$FORCE" = true ]; then
                kill -9 $saved_pid 2>/dev/null || true
            else
                kill $saved_pid 2>/dev/null || true
            fi
        else
            log_info "Process $saved_pid is not running"
        fi
        
        rm -f "$pid_file"
        log_success "Removed PID file"
    fi
}

# Main function
main() {
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    
    log_info "=========================================="
    log_info "gRPC Server Stop Script"
    log_info "=========================================="
    echo
    
    # Parse arguments
    parse_arguments "$@"
    
    # Determine signal
    local signal="TERM"
    if [ "$FORCE" = true ]; then
        signal="KILL"
        log_warning "Force mode enabled - using SIGKILL"
    fi
    
    # Kill by port
    kill_by_port "$PORT" "$signal"
    
    # Kill by process name (Java specific)
    kill_by_name "ProtoServer" "$signal"
    
    # Clean up PID file
    cleanup_pid_file
    
    echo
    log_info "=========================================="
    log_success "Server stop operation completed"
    log_info "=========================================="
    
    # Verify port is free
    echo
    log_info "Verifying port $PORT is free..."
    if lsof -ti :$PORT > /dev/null 2>&1; then
        log_error "Port $PORT is still in use!"
        if [ "$VERBOSE" = true ]; then
            lsof -i :$PORT
        fi
        exit 1
    else
        log_success "Port $PORT is free"
    fi
}

# Run main function
main "$@"
