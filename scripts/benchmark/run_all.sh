#!/bin/bash
#
# run_all.sh — Run ghz benchmarks against all language server Docker images.
#
# For each language, this script:
#   1. Starts the language server container
#   2. Waits for port 9996 to be available
#   3. Runs ghz benchmark (unary Talk RPC)
#   4. Collects results as JSON
#   5. Stops the container
#
# After all languages are benchmarked, a summary table is printed
# comparing RPS and latency percentiles across languages.
#
# Usage:
#   ./run_all.sh [options]
#
# Options:
#   -n <count>      Total requests per language (default: 1000)
#   -c <concurrency> Concurrent requests (default: 10)
#   -r <rpc>        RPC method: talk|server-stream|client-stream|bidi (default: talk)
#   -l <lang>       Benchmark a single language (skip others)
#   -k              Keep containers running after benchmark (default: remove)
#
# Examples:
#   ./run_all.sh                         # Benchmark all languages with defaults
#   ./run_all.sh -n 5000 -c 50           # Higher load
#   ./run_all.sh -l go -n 10000          # Benchmark only Go
#   ./run_all.sh -r bidi -n 200 -c 5     # Test bidirectional streaming
#
# Requires: ghz, docker, jq
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_SCRIPT="$SCRIPT_DIR/ghz_benchmark.sh"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

# All languages with Docker images
ALL_LANGS=(go python java cpp rust nodejs csharp kotlin swift dart php ts)

# Parse args
TOTAL=1000
CONCURRENCY=10
RPC="talk"
SINGLE_LANG=""
KEEP=false

while getopts "n:c:r:l:k" opt; do
  case $opt in
    n) TOTAL="$OPTARG" ;;
    c) CONCURRENCY="$OPTARG" ;;
    r) RPC="$OPTARG" ;;
    l) SINGLE_LANG="$OPTARG" ;;
    k) KEEP=true ;;
    *) echo "Unknown option: -$opt" >&2; exit 1 ;;
  esac
done

LANGS=()
if [[ -n "$SINGLE_LANG" ]]; then
  LANGS=("$SINGLE_LANG")
else
  LANGS=("${ALL_LANGS[@]}")
fi

# Docker image name helper
img_name() {
  local lang="$1"
  [[ "$lang" == "nodejs" ]] && echo "feuyeux/grpc_server_node:1.0.0" || echo "feuyeux/grpc_server_${lang}:1.0.0"
}

ctr_name() {
  local lang="$1"
  [[ "$lang" == "nodejs" ]] && echo "grpc_bench_node" || echo "grpc_bench_${lang}"
}

# Check prerequisites
for cmd in ghz docker jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd not found" >&2
    exit 1
  fi
done

echo "================================================================"
echo "  Cross-Language ghz Benchmark"
echo "================================================================"
echo "  Languages:  ${LANGS[*]}"
echo "  RPC:        $RPC"
echo "  Requests:   $TOTAL"
echo "  Concurrent: $CONCURRENCY"
echo "================================================================"
echo ""

# Cleanup any existing containers
for lang in "${LANGS[@]}"; do
  docker rm -f "$(ctr_name "$lang")" 2>/dev/null || true
done

# Kill anything on port 9996
fuser -k 9996/tcp 2>/dev/null || true

SUMMARY_FILE="$RESULTS_DIR/summary_$(date +%Y%m%d_%H%M%S).json"
echo "[" > "$SUMMARY_FILE"

FIRST=true
PASS=0
FAIL=0

for lang in "${LANGS[@]}"; do
  SERVER_IMG=$(img_name "$lang")
  SVR_CTR=$(ctr_name "$lang")
  OUTPUT="$RESULTS_DIR/${lang}_${RPC}.json"

  echo "--- [$lang] ---"

  # Start server container
  if ! docker run -d --rm --name "$SVR_CTR" -p 9996:9996 "$SERVER_IMG" >/dev/null 2>&1; then
    echo "  FAIL: could not start server container ($SERVER_IMG)"
    if [[ "$FIRST" == "false" ]]; then echo "," >> "$SUMMARY_FILE"; fi
    echo "{\"lang\":\"$lang\",\"status\":\"fail\",\"reason\":\"server start\"}" >> "$SUMMARY_FILE"
    FIRST=false
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
    echo "  FAIL: port 9996 never opened"
    docker rm -f "$SVR_CTR" 2>/dev/null || true
    if [[ "$FIRST" == "false" ]]; then echo "," >> "$SUMMARY_FILE"; fi
    echo "{\"lang\":\"$lang\",\"status\":\"fail\",\"reason\":\"port timeout\"}" >> "$SUMMARY_FILE"
    FIRST=false
    FAIL=$((FAIL+1))
    continue
  fi

  # Run benchmark
  echo "  Running ghz benchmark..."
  if "$BENCH_SCRIPT" localhost 9996 -n "$TOTAL" -c "$CONCURRENCY" -r "$RPC" -o "$OUTPUT" 2>&1 | sed 's/^/  /'; then
    # Extract results for summary
    RPS=$(jq -r '.rps // "n/a"' "$OUTPUT" 2>/dev/null || echo "n/a")
    P50=$(jq -r '.latencies.p50 // "n/a"' "$OUTPUT" 2>/dev/null || echo "n/a")
    P90=$(jq -r '.latencies.p90 // "n/a"' "$OUTPUT" 2>/dev/null || echo "n/a")
    P99=$(jq -r '.latencies.p99 // "n/a"' "$OUTPUT" 2>/dev/null || echo "n/a")
    ERRORS=$(jq -r '.errorCount // 0' "$OUTPUT" 2>/dev/null || echo "0")

    echo "  PASS: RPS=$RPS, p50=$P50, p90=$P90, p99=$P99, errors=$ERRORS"
    if [[ "$FIRST" == "false" ]]; then echo "," >> "$SUMMARY_FILE"; fi
    echo "{\"lang\":\"$lang\",\"status\":\"pass\",\"rps\":$RPS,\"p50\":\"$P50\",\"p90\":\"$P90\",\"p99\":\"$P99\",\"errors\":$ERRORS}" >> "$SUMMARY_FILE"
    FIRST=false
    PASS=$((PASS+1))
  else
    echo "  FAIL: ghz benchmark failed"
    if [[ "$FIRST" == "false" ]]; then echo "," >> "$SUMMARY_FILE"; fi
    echo "{\"lang\":\"$lang\",\"status\":\"fail\",\"reason\":\"ghz error\"}" >> "$SUMMARY_FILE"
    FIRST=false
    FAIL=$((FAIL+1))
  fi

  # Stop container
  if [[ "$KEEP" != "true" ]]; then
    docker rm -f "$SVR_CTR" 2>/dev/null || true
  fi

  # Brief cooldown
  sleep 2
done

echo "" >> "$SUMMARY_FILE"
echo "]" >> "$SUMMARY_FILE"

# Print summary table
echo ""
echo "================================================================"
echo "  SUMMARY: $PASS passed, $FAIL failed (of ${#LANGS[@]})"
echo "================================================================"
printf "%-12s %-8s %-12s %-12s %-12s %-8s\n" "Language" "Status" "RPS" "p50" "p99" "Errors"
printf "%-12s %-8s %-12s %-12s %-12s %-8s\n" "--------" "------" "---" "---" "---" "------"
jq -r '.[] | "\(.lang)\t\(.status)\t\(.rps // "n/a")\t\(.p50 // "n/a")\t\(.p99 // "n/a")\t\(.errors // "n/a")"' "$SUMMARY_FILE" | while IFS=$'\t' read -r lang status rps p50 p99 errors; do
  printf "%-12s %-8s %-12s %-12s %-12s %-8s\n" "$lang" "$status" "$rps" "$p50" "$p99" "$errors"
done
echo ""
echo "  Full results: $SUMMARY_FILE"
echo "  Individual:   $RESULTS_DIR/<lang>_<rpc>.json"
