#!/usr/bin/env bash
# Stop script for the nodejs gRPC server. Mirrors the structure of
# hello-grpc-java/scripts/stop_server.sh so all 12 languages expose
# the same --port / --force / --verbose interface.
#
# Defaults:
#   port: 9996        (the same default that server_start.sh binds)
#   proc: "src/server/index\.js"   (the running command we pgrep against)
#
# Usage:
#   ./stop_server.sh                  # graceful TERM, then KILL after 5s
#   ./stop_server.sh --force          # SIGKILL immediately
#   ./stop_server.sh --port=9997      # custom port
#   ./stop_server.sh --verbose        # show what we kill

set -e

# ANSI colors via $'...' quoting so ESC (0x1b) is real, not the
# literal 4-char sequence backslash-zero-three-three.
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[1;33m'
readonly BLUE=$'\033[0;34m'
readonly NC=$'\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Defaults
PORT="9996"
FORCE=false
VERBOSE=false
PROCESS_PATTERN="src/server/index\.js"

show_help() {
    cat <<EOF
gRPC Server Stop Script (nodejs)

Usage: $0 [options]

Options:
  --port=PORT       Port number to check (default: $PORT)
  --force, -f       Force kill processes (SIGKILL)
  --verbose, -v     Verbose output
  --help, -h        Show this help message

Examples:
  $0                        # Stop server on port $PORT
  $0 --port=9997           # Stop server on port 9997
  $0 --force               # Force kill server processes
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port=*)  PORT="${1#*=}"; shift ;;
            --force|-f) FORCE=true; shift ;;
            --verbose|-v) VERBOSE=true; shift ;;
            --help|-h)  show_help; exit 0 ;;
            *) log_error "Unknown option: $1"; echo "Use --help"; exit 1 ;;
        esac
    done
}

kill_by_port() {
    local port=$1 signal=${2:-TERM}
    log_info "Searching for processes listening on port $port..."
    local pids
    pids=$(lsof -ti :"$port" 2>/dev/null || true)
    if [ -z "$pids" ]; then
        log_info "No processes found on port $port"
        return 0
    fi
    log_info "Found PIDs: $pids"
    for pid in $pids; do
        if [ "$VERBOSE" = true ]; then
            local comm
            comm=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            log_info "Killing PID $pid ($comm) with SIG$signal"
        else
            log_info "Killing PID $pid with SIG$signal"
        fi
        if kill -s "$signal" "$pid" 2>/dev/null; then
            if [ "$signal" = "TERM" ]; then
                local count=0
                while kill -0 "$pid" 2>/dev/null && [ "$count" -lt 10 ]; do
                    sleep 0.5
                    count=$((count + 1))
                done
                if kill -0 "$pid" 2>/dev/null; then
                    log_warning "PID $pid did not exit gracefully, sending SIGKILL"
                    kill -9 "$pid" 2>/dev/null || true
                fi
            fi
        else
            log_warning "Failed to kill PID $pid (may already be gone)"
        fi
    done
}

kill_by_pattern() {
    local pattern=$1 signal=${2:-TERM}
    log_info "Searching for processes matching '$pattern'..."
    if [ "$VERBOSE" = true ]; then
        pgrep -fl "$pattern" 2>/dev/null || true
    fi
    if ! pgrep -f "$pattern" >/dev/null 2>&1; then
        log_info "No processes match '$pattern'"
        return 0
    fi
    if [ "$signal" = "KILL" ]; then
        pkill -9 -f "$pattern" 2>/dev/null || true
    else
        pkill -f "$pattern" 2>/dev/null || true
    fi
    sleep 1
    if pgrep -f "$pattern" >/dev/null 2>&1; then
        log_warning "Some '$pattern' processes remain"
        [ "$VERBOSE" = true ] && pgrep -fl "$pattern" || true
    else
        log_success "All '$pattern' processes terminated"
    fi
}

main() {
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    log_info "==============================="
    log_info "gRPC nodejs Server Stop Script"
    log_info "==============================="
    echo
    parse_arguments "$@"
    local signal="TERM"
    [ "$FORCE" = true ] && signal="KILL" && log_warning "Force mode: using SIGKILL"
    kill_by_port   "$PORT" "$signal"
    kill_by_pattern "$PROCESS_PATTERN" "$signal"
    echo
    log_info "Verifying port $PORT is free..."
    if lsof -ti :"$PORT" >/dev/null 2>&1; then
        log_error "Port $PORT is still in use!"
        [ "$VERBOSE" = true ] && lsof -i :"$PORT"
        exit 1
    fi
    log_success "Port $PORT is free"
}

main "$@"
