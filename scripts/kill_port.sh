#!/usr/bin/env bash
# Universal script to kill processes using a specific port
# Usage: ./kill_port.sh <port> [--force]

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Show usage
show_usage() {
    cat << EOF
Kill processes using a specific port

Usage: $(basename "$0") <port> [options]

Arguments:
  port              Port number (required)

Options:
  --force, -f       Force kill (SIGKILL instead of SIGTERM)
  --verbose, -v     Show detailed process information
  --help, -h        Show this help message

Examples:
  $(basename "$0") 9996              # Kill processes on port 9996
  $(basename "$0") 8080 --force      # Force kill on port 8080
  $(basename "$0") 3000 --verbose    # Verbose mode
EOF
}

# Parse arguments
PORT=""
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$PORT" ]; then
                PORT="$1"
            else
                log_error "Too many arguments"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate port
if [ -z "$PORT" ]; then
    log_error "Port number is required"
    show_usage
    exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    log_error "Invalid port number: $PORT (must be 1-65535)"
    exit 1
fi

log_info "=========================================="
log_info "Kill Port Utility"
log_info "Target port: $PORT"
log_info "Force mode: $([ "$FORCE" = true ] && echo "Yes (SIGKILL)" || echo "No (SIGTERM)")"
log_info "=========================================="
echo

# Find processes using the port
log_info "Searching for processes using port $PORT..."

PIDS=$(lsof -ti :$PORT 2>/dev/null || true)

if [ -z "$PIDS" ]; then
    log_success "No processes found using port $PORT"
    exit 0
fi

log_info "Found process(es): $PIDS"
echo

# Show process details if verbose
if [ "$VERBOSE" = true ]; then
    log_info "Process details:"
    for pid in $PIDS; do
        if ps -p $pid > /dev/null 2>&1; then
            ps -p $pid -o pid,user,command || true
        fi
    done
    echo
fi

# Kill processes
SIGNAL="TERM"
SIGNAL_NUM=15
if [ "$FORCE" = true ]; then
    SIGNAL="KILL"
    SIGNAL_NUM=9
fi

for pid in $PIDS; do
    if ! kill -0 $pid 2>/dev/null; then
        log_warning "Process $pid no longer exists (may have already exited)"
        continue
    fi
    
    # Get process name for logging
    PROC_NAME=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
    
    log_info "Killing process $pid ($PROC_NAME) with SIG$SIGNAL..."
    
    if kill -$SIGNAL_NUM $pid 2>/dev/null; then
        log_success "Sent SIG$SIGNAL to process $pid"
        
        # Wait for graceful termination (if SIGTERM)
        if [ "$SIGNAL" = "TERM" ]; then
            COUNT=0
            while kill -0 $pid 2>/dev/null && [ $COUNT -lt 20 ]; do
                sleep 0.5
                COUNT=$((COUNT + 1))
            done
            
            # Check if still running
            if kill -0 $pid 2>/dev/null; then
                log_warning "Process $pid didn't terminate gracefully after 10 seconds"
                log_warning "Force killing process $pid..."
                kill -9 $pid 2>/dev/null || true
                sleep 1
                
                if kill -0 $pid 2>/dev/null; then
                    log_error "Failed to kill process $pid"
                else
                    log_success "Process $pid force killed"
                fi
            else
                log_success "Process $pid terminated gracefully"
            fi
        else
            sleep 1
            if kill -0 $pid 2>/dev/null; then
                log_error "Failed to kill process $pid"
            else
                log_success "Process $pid terminated"
            fi
        fi
    else
        log_error "Failed to send signal to process $pid (permission denied?)"
    fi
done

echo
log_info "=========================================="

# Verify port is free
log_info "Verifying port $PORT is now free..."
sleep 1

if lsof -ti :$PORT > /dev/null 2>&1; then
    REMAINING=$(lsof -ti :$PORT 2>/dev/null | wc -l | tr -d ' ')
    log_error "Port $PORT is still in use by $REMAINING process(es)"
    
    if [ "$VERBOSE" = true ]; then
        echo
        log_info "Remaining processes:"
        lsof -i :$PORT || true
    fi
    
    exit 1
else
    log_success "Port $PORT is now free"
fi

log_info "=========================================="
