#!/usr/bin/env bash

# Common utilities for proxy scripts
# Provides shared functions for language detection, command mapping, and process management

set -euo pipefail

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_PARAMS=1
readonly EXIT_ENV_ERROR=2
readonly EXIT_PROCESS_ERROR=3
readonly EXIT_COMM_ERROR=4
readonly EXIT_TIMEOUT=5

# Supported languages
readonly SUPPORTED_LANGUAGES=(
  "java"
  "go"
  "python"
  "nodejs"
  "typescript"
  "rust"
  "cpp"
  "csharp"
  "kotlin"
  "swift"
  "dart"
  "php"
)

# Languages that support proxy mode
readonly PROXY_SUPPORTED_LANGUAGES=(
  "java"
  "go"
  "python"
  "nodejs"
  "typescript"
  "rust"
  "cpp"
  "csharp"
  "kotlin"
  "swift"
  "dart"
  "php"
)

# Validate that a language is supported
# Args:
#   $1 - language name
# Returns:
#   0 if supported, 1 if not
validate_language() {
  local lang="$1"
  
  for supported in "${SUPPORTED_LANGUAGES[@]}"; do
    if [[ "$lang" == "$supported" ]]; then
      return 0
    fi
  done
  
  return 1
}

# Check if a language supports proxy mode
# Args:
#   $1 - language name
# Returns:
#   0 if proxy is supported, 1 if not
supports_proxy() {
  local lang="$1"
  
  for supported in "${PROXY_SUPPORTED_LANGUAGES[@]}"; do
    if [[ "$lang" == "$supported" ]]; then
      return 0
    fi
  done
  
  return 1
}

# Get the directory name for a language implementation
# Args:
#   $1 - language name
# Returns:
#   Directory name (e.g., "hello-grpc-java")
get_language_dir() {
  local lang="$1"
  
  case "$lang" in
    java)
      echo "hello-grpc-java"
      ;;
    go)
      echo "hello-grpc-go"
      ;;
    python)
      echo "hello-grpc-python"
      ;;
    nodejs)
      echo "hello-grpc-nodejs"
      ;;
    typescript)
      echo "hello-grpc-ts"
      ;;
    rust)
      echo "hello-grpc-rust"
      ;;
    cpp)
      echo "hello-grpc-cpp"
      ;;
    csharp)
      echo "hello-grpc-csharp"
      ;;
    kotlin)
      echo "hello-grpc-kotlin"
      ;;
    swift)
      echo "hello-grpc-swift"
      ;;
    dart)
      echo "hello-grpc-dart"
      ;;
    php)
      echo "hello-grpc-php"
      ;;
    *)
      echo ""
      return 1
      ;;
  esac
}

# Get the server command for a language
# Args:
#   $1 - language name
#   $2 - port (optional, for backend server)
#   $3 - backend host (optional, for proxy mode)
#   $4 - backend port (optional, for proxy mode)
#   $5 - tls flag (optional, "true" or "false")
# Returns:
#   Command string to start the server
get_server_command() {
  local lang="$1"
  local port="${2:-}"
  local backend_host="${3:-}"
  local backend_port="${4:-}"
  local tls="${5:-false}"
  
  # Build environment variable prefix
  local env_vars=""
  
  if [[ -n "$port" ]]; then
    env_vars="${env_vars}GRPC_SERVER_PORT=$port "
  fi
  
  if [[ -n "$backend_host" && -n "$backend_port" ]]; then
    env_vars="${env_vars}GRPC_HELLO_BACKEND=$backend_host "
    env_vars="${env_vars}GRPC_HELLO_BACKEND_PORT=$backend_port "
  fi
  
  if [[ "$tls" == "true" ]]; then
    env_vars="${env_vars}GRPC_HELLO_SECURE=Y "
  fi
  
  case "$lang" in
    java)
      echo "${env_vars}java -jar target/hello-grpc-java-server.jar"
      ;;
    go)
      echo "${env_vars}go run server/proto_server.go"
      ;;
    python)
      echo "${env_vars}python server/protoServer.py"
      ;;
    nodejs)
      echo "${env_vars}npm run server"
      ;;
    typescript)
      echo "${env_vars}yarn server"
      ;;
    rust)
      echo "${env_vars}cargo run --bin hello_server"
      ;;
    cpp)
      echo "${env_vars}bazel-bin/hello_server"
      ;;
    csharp)
      echo "${env_vars}dotnet run --project HelloServer"
      ;;
    kotlin)
      echo "${env_vars}gradle :server:ProtoServer"
      ;;
    swift)
      # Use pre-built binary to avoid SwiftPM lock contention
      echo "${env_vars}.build/debug/HelloServer"
      ;;
    dart)
      echo "${env_vars}dart run server.dart"
      ;;
    php)
      echo "${env_vars}php hello_server.php"
      ;;
    *)
      echo ""
      return 1
      ;;
  esac
}

# Get the client command for a language
# Args:
#   $1 - language name
#   $2 - server host (optional)
#   $3 - server port (optional)
#   $4 - tls flag (optional, "true" or "false")
# Returns:
#   Command string to start the client
get_client_command() {
  local lang="$1"
  local server_host="${2:-}"
  local server_port="${3:-}"
  local tls="${4:-false}"
  
  # Build environment variable prefix
  local env_vars=""
  
  if [[ -n "$server_host" ]]; then
    env_vars="${env_vars}GRPC_SERVER=$server_host "
  fi
  
  if [[ -n "$server_port" ]]; then
    env_vars="${env_vars}GRPC_SERVER_PORT=$server_port "
  fi
  
  if [[ "$tls" == "true" ]]; then
    env_vars="${env_vars}GRPC_HELLO_SECURE=Y "
  fi
  
  case "$lang" in
    java)
      echo "${env_vars}java -jar target/hello-grpc-java-client.jar"
      ;;
    go)
      echo "${env_vars}go run client/proto_client.go"
      ;;
    python)
      echo "${env_vars}python client/protoClient.py"
      ;;
    nodejs)
      echo "${env_vars}npm run client"
      ;;
    typescript)
      echo "${env_vars}yarn client"
      ;;
    rust)
      echo "${env_vars}cargo run --bin proto-client"
      ;;
    cpp)
      echo "${env_vars}bazel-bin/hello_client"
      ;;
    csharp)
      echo "${env_vars}dotnet run --project HelloClient"
      ;;
    kotlin)
      echo "${env_vars}gradle :client:ProtoClient"
      ;;
    swift)
      # Use pre-built binary to avoid SwiftPM lock contention
      echo "${env_vars}.build/debug/HelloClient"
      ;;
    dart)
      echo "${env_vars}dart run client.dart"
      ;;
    php)
      echo "${env_vars}php hello_client.php"
      ;;
    *)
      echo ""
      return 1
      ;;
  esac
}

# Log a message with timestamp
# Args:
#   $1 - log level (INFO, WARN, ERROR)
#   $2 - message
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  echo "[$level] $timestamp $message"
}

# Wait for a port to be ready (listening)
# Args:
#   $1 - port number
#   $2 - timeout in seconds (default: 30)
# Returns:
#   0 if port is ready, 1 if timeout
wait_for_ready() {
  local port="$1"
  local timeout="${2:-30}"
  local elapsed=0
  local check_interval=1
  local last_log_time=0
  local log_interval=5  # Log status every 5 seconds
  
  log "INFO" "Waiting for port $port to be ready (timeout: ${timeout}s)..."
  
  while [[ $elapsed -lt $timeout ]]; do
    if command -v nc >/dev/null 2>&1; then
      # Use netcat if available
      if nc -z localhost "$port" 2>/dev/null; then
        log "INFO" "Port $port is ready (after ${elapsed}s)"
        return 0
      fi
    elif command -v lsof >/dev/null 2>&1; then
      # Use lsof if available
      if lsof -i :"$port" -sTCP:LISTEN >/dev/null 2>&1; then
        log "INFO" "Port $port is ready (after ${elapsed}s)"
        return 0
      fi
    else
      # Fallback: try to connect with bash
      if timeout 1 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
        log "INFO" "Port $port is ready (after ${elapsed}s)"
        return 0
      fi
    fi
    
    # Log wait status periodically
    if [[ $((elapsed - last_log_time)) -ge $log_interval ]]; then
      log "INFO" "Still waiting for port $port... (${elapsed}s elapsed, $((timeout - elapsed))s remaining)"
      last_log_time=$elapsed
    fi
    
    sleep $check_interval
    ((elapsed += check_interval))
  done
  
  log "ERROR" "Timeout waiting for port $port after ${timeout}s"
  return 1
}

# Track process IDs for cleanup
declare -a TRACKED_PIDS=()

# Add a process ID to the tracking list
# Args:
#   $1 - process ID
track_process() {
  local pid="$1"
  TRACKED_PIDS+=("$pid")
  log "INFO" "Tracking process $pid"
}

# Kill a single process gracefully with timeout and fallback to force kill
# Args:
#   $1 - process ID
#   $2 - process name/description (optional, for logging)
#   $3 - timeout in seconds (optional, default: 5)
# Returns:
#   0 if process terminated, 1 if process didn't exist
kill_process_gracefully() {
  local pid="$1"
  local name="${2:-process}"
  local timeout="${3:-5}"
  
  # Check if process exists
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi
  
  log "INFO" "Terminating $name (PID: $pid)"
  kill "$pid" 2>/dev/null || true
  
  # Wait for graceful termination
  local wait_time=0
  while [[ $wait_time -lt $timeout ]]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      log "INFO" "$name terminated successfully"
      return 0
    fi
    sleep 1
    ((wait_time++))
  done
  
  # Force kill if still running
  log "WARN" "Force killing $name (PID: $pid) with SIGKILL"
  kill -9 "$pid" 2>/dev/null || true
  
  # Verify force kill worked
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    log "ERROR" "Failed to kill $name (PID: $pid)"
    return 1
  fi
  
  return 0
}

# Cleanup tracked processes
# Terminates all tracked processes gracefully
cleanup_processes() {
  if [[ ${#TRACKED_PIDS[@]} -eq 0 ]]; then
    log "INFO" "No processes to clean up"
    return 0
  fi
  
  log "INFO" "Cleaning up ${#TRACKED_PIDS[@]} tracked processes..."
  
  # Use the shared kill_process_gracefully function for each tracked process
  for pid in "${TRACKED_PIDS[@]}"; do
    kill_process_gracefully "$pid" "tracked process" 5 || true
  done
  
  TRACKED_PIDS=()
  log "INFO" "Cleanup complete"
}

# Setup signal handlers for cleanup
setup_cleanup_handlers() {
  trap cleanup_processes EXIT INT TERM
}
