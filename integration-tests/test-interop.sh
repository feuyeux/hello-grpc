#!/bin/bash
#
# test-interop.sh — Cross-language gRPC interoperability test matrix.
#
# For each (client_lang, server_lang) pair:
#   1. Start server_lang Docker container on port 9996
#   2. Run client_lang Docker container pointing at the server
#   3. Check client output for success markers
#   4. Record pass/fail
#
# Output: Markdown table + JSON artifact for CI upload.
#
# Usage:
#   ./test-interop.sh [options]
#
# Options:
#   -s <langs>   Server languages (comma-separated, default: go,java,python)
#   -c <langs>   Client languages (comma-separated, default: go,java,python)
#   -o <file>    JSON output file (default: interop-results.json)
#   -k           Keep containers running (default: remove)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/interop-results.json"

# Default: test 5 server langs x 5 client langs = 25 pairs
SERVER_LANGS="go,java,python,node,rust"
CLIENT_LANGS="go,java,python,node,rust"
KEEP=false

while getopts "s:c:o:k" opt; do
  case $opt in
    s) SERVER_LANGS="$OPTARG" ;;
    c) CLIENT_LANGS="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    k) KEEP=true ;;
    *) echo "Unknown option: -$opt" >&2; exit 1 ;;
  esac
done

IFS=',' read -ra SERVERS <<< "$SERVER_LANGS"
IFS=',' read -ra CLIENTS <<< "$CLIENT_LANGS"

# Docker image name helper (matches smoke_test_all.sh convention)
img_name() {
  local lang="$1" comp="$2"
  [[ "$lang" == "nodejs" ]] && echo "feuyeux/grpc_${comp}_node:1.0.0" || echo "feuyeux/grpc_${comp}_${lang}:1.0.0"
}

ctr_name() {
  local lang="$1" comp="$2"
  [[ "$lang" == "nodejs" ]] && echo "grpc_interop_${comp}_node" || echo "grpc_interop_${comp}_${lang}"
}

PASS=0
FAIL=0
TOTAL_PAIRS=0

echo "================================================================"
echo "  Cross-Language Interop Test Matrix"
echo "================================================================"
echo "  Servers: ${SERVERS[*]}"
echo "  Clients: ${CLIENTS[*]}"
echo "================================================================"
echo ""

# Start JSON output
echo "{" > "$OUTPUT_FILE"
echo '  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",' >> "$OUTPUT_FILE"
echo '  "servers": ["'$(IFS=,; echo "${SERVERS[*]}")'"],' >> "$OUTPUT_FILE"
echo '  "clients": ["'$(IFS=,; echo "${CLIENTS[*]}")'"],' >> "$OUTPUT_FILE"
echo '  "results": [' >> "$OUTPUT_FILE"

FIRST_RESULT=true

# Print markdown table header
printf "| Client \\ Server |"
for server in "${SERVERS[@]}"; do
  printf " %s |" "$server"
done
printf "\n"
printf "|---|"
for server in "${SERVERS[@]}"; do
  printf "---|"
done
printf "\n"

for client in "${CLIENTS[@]}"; do
  printf "| %s |" "$client"
  for server in "${SERVERS[@]}"; do
    TOTAL_PAIRS=$((TOTAL_PAIRS+1))
    SVR_IMG=$(img_name "$server" server)
    CLI_IMG=$(img_name "$client" client)
    SVR_CTR=$(ctr_name "$server" server)
    CLI_CTR=$(ctr_name "$client" client)

    # Cleanup any existing containers
    docker rm -f "$SVR_CTR" "$CLI_CTR" 2>/dev/null || true

    # Start server
    if ! docker run -d --rm --name "$SVR_CTR" -p 9996:9996 "$SVR_IMG" >/dev/null 2>&1; then
      printf " FAIL |"
      if [[ "$FIRST_RESULT" == "false" ]]; then echo "," >> "$OUTPUT_FILE"; fi
      echo "    {\"client\":\"$client\",\"server\":\"$server\",\"status\":\"fail\",\"reason\":\"server start\"}" >> "$OUTPUT_FILE"
      FIRST_RESULT=false
      FAIL=$((FAIL+1))
      continue
    fi

    # Wait for port 9996
    ok=0
    for i in $(seq 1 30); do
      if (echo > /dev/tcp/127.0.0.1/9996) 2>/dev/null; then ok=1; break; fi
      sleep 1
    done
    if [[ $ok -eq 0 ]]; then
      docker rm -f "$SVR_CTR" 2>/dev/null || true
      printf " FAIL |"
      if [[ "$FIRST_RESULT" == "false" ]]; then echo "," >> "$OUTPUT_FILE"; fi
      echo "    {\"client\":\"$client\",\"server\":\"$server\",\"status\":\"fail\",\"reason\":\"port timeout\"}" >> "$OUTPUT_FILE"
      FIRST_RESULT=false
      FAIL=$((FAIL+1))
      continue
    fi

    # Run client
    CLI_LOG=$(mktemp)
    cli_exit=0
    timeout 60 docker run --rm --name "$CLI_CTR" \
      -e GRPC_SERVER=host.docker.internal \
      "$CLI_IMG" > "$CLI_LOG" 2>&1 || cli_exit=$?

    # Stop server
    if [[ "$KEEP" != "true" ]]; then
      docker rm -f "$SVR_CTR" 2>/dev/null || true
    fi

    # Check for success markers (matching smoke_test_all.sh logic)
    reason=""
    if [[ $cli_exit -ne 0 ]]; then
      reason="client exit=$cli_exit"
    elif ! grep -qiE "All gRPC calls completed successfully|completed successfully|bidirectional stream completed|client execution completed|all calls completed|completed.*gRPC" "$CLI_LOG"; then
      if grep -qiE "fatal|panic|unhandled|connection refused|deadline exceeded" "$CLI_LOG"; then
        reason="client log shows errors"
      elif ! grep -qE "data=|Received|Response|response" "$CLI_LOG"; then
        reason="no success marker"
      fi
    fi

    if [[ -z "$reason" ]]; then
      printf " PASS |"
      if [[ "$FIRST_RESULT" == "false" ]]; then echo "," >> "$OUTPUT_FILE"; fi
      echo "    {\"client\":\"$client\",\"server\":\"$server\",\"status\":\"pass\"}" >> "$OUTPUT_FILE"
      FIRST_RESULT=false
      PASS=$((PASS+1))
    else
      printf " FAIL |"
      if [[ "$FIRST_RESULT" == "false" ]]; then echo "," >> "$OUTPUT_FILE"; fi
      echo "    {\"client\":\"$client\",\"server\":\"$server\",\"status\":\"fail\",\"reason\":\"$reason\"}" >> "$OUTPUT_FILE"
      FIRST_RESULT=false
      FAIL=$((FAIL+1))
    fi

    rm -f "$CLI_LOG"
    sleep 1
  done
  printf "\n"
done

# Close JSON
echo "" >> "$OUTPUT_FILE"
echo "  ]" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

echo ""
echo "================================================================"
echo "  INTEROP SUMMARY: $PASS passed, $FAIL failed (of $TOTAL_PAIRS pairs)"
echo "================================================================"
echo "  Results JSON: $OUTPUT_FILE"
echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
