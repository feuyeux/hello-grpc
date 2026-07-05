#!/bin/bash
#
# ghz_benchmark.sh — Run a ghz benchmark against a single gRPC server.
#
# Usage:
#   ./ghz_benchmark.sh <host> <port> [options]
#
# Options:
#   -n <count>      Total number of requests (default: 1000)
#   -c <concurrency> Concurrent requests (default: 10)
#   -r <rpc>        RPC method: talk|server-stream|client-stream|bidi (default: talk)
#   -t              Use TLS (default: insecure)
#   -o <file>       Output JSON file (default: results/<host>_<port>_<rpc>_<timestamp>.json)
#
# Examples:
#   ./ghz_benchmark.sh localhost 9996
#   ./ghz_benchmark.sh localhost 9996 -n 5000 -c 50
#   ./ghz_benchmark.sh localhost 9996 -r bidi -n 200 -c 5
#
# Requires: ghz (https://github.com/bojand/ghz)
#
set -euo pipefail

# Resolve repo root so we can find the proto file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROTO_FILE="$REPO_ROOT/proto/landing.proto"

if [[ ! -f "$PROTO_FILE" ]]; then
  echo "ERROR: proto file not found at $PROTO_FILE" >&2
  exit 1
fi

if ! command -v ghz &>/dev/null; then
  echo "ERROR: ghz not found. Install: brew install ghz" >&2
  exit 1
fi

# --- Parse args ---
HOST="${1:?Usage: $0 <host> <port> [options]}"
PORT="${2:?Usage: $0 <host> <port> [options]}"
shift 2

TOTAL=1000
CONCURRENCY=10
RPC="talk"
USE_TLS=false
OUTPUT=""

while getopts "n:c:r:to:" opt; do
  case $opt in
    n) TOTAL="$OPTARG" ;;
    c) CONCURRENCY="$OPTARG" ;;
    r) RPC="$OPTARG" ;;
    t) USE_TLS=true ;;
    o) OUTPUT="$OPTARG" ;;
    *) echo "Unknown option: -$opt" >&2; exit 1 ;;
  esac
done

# --- Build ghz call config ---
SERVICE="hello.LandingService"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

case "$RPC" in
  talk)
    METHOD="$SERVICE/Talk"
    DATA='{"data":"0","meta":"benchmark"}'
    ;;
  server-stream)
    METHOD="$SERVICE/TalkOneAnswerMore"
    DATA='{"data":"0,1,2","meta":"benchmark"}'
    ;;
  client-stream)
    METHOD="$SERVICE/TalkMoreAnswerOne"
    DATA='[{"data":"0","meta":"benchmark"},{"data":"1","meta":"benchmark"},{"data":"2","meta":"benchmark"}]'
    ;;
  bidi)
    METHOD="$SERVICE/TalkBidirectional"
    DATA='[{"data":"0","meta":"benchmark"},{"data":"1","meta":"benchmark"},{"data":"2","meta":"benchmark"}]'
    ;;
  *)
    echo "ERROR: unknown RPC method '$RPC'. Use: talk|server-stream|client-stream|bidi" >&2
    exit 1
    ;;
esac

if [[ -z "$OUTPUT" ]]; then
  mkdir -p "$SCRIPT_DIR/results"
  OUTPUT="$SCRIPT_DIR/results/${HOST}_${PORT}_${RPC}_${TIMESTAMP}.json"
fi

ADDRESS="${HOST}:${PORT}"

echo "============================================"
echo "  ghz Benchmark"
echo "============================================"
echo "  Target:     $ADDRESS"
echo "  RPC:        $METHOD"
echo "  Requests:   $TOTAL"
echo "  Concurrent: $CONCURRENCY"
echo "  TLS:        $USE_TLS"
echo "  Output:     $OUTPUT"
echo "============================================"

# --- Build ghz flags ---
GHZ_FLAGS=(
  --proto "$PROTO_FILE"
  --call "$METHOD"
  -d "$DATA"
  -n "$TOTAL"
  -c "$CONCURRENCY"
  --connections="$CONCURRENCY"
  -O json
  -o "$OUTPUT"
)

if [[ "$USE_TLS" == "true" ]]; then
  GHZ_FLAGS+=(
    --cname=hello.grpc.io
    --cert="${CERT_BASE_PATH:-/var/hello_grpc/client_certs}/full_chain.pem"
    --key="${CERT_BASE_PATH:-/var/hello_grpc/client_certs}/private.pkcs8.key"
    --cacert="${CERT_BASE_PATH:-/var/hello_grpc/client_certs}/myssl_root.cer"
  )
else
  GHZ_FLAGS+=(--insecure)
fi

# --- Run benchmark ---
echo "Running ghz..."
ghz "${GHZ_FLAGS[@]}" "$ADDRESS"

if [[ -f "$OUTPUT" ]]; then
  echo ""
  echo "--- Results Summary ---"
  # Extract key metrics from the JSON output
  if command -v jq &>/dev/null; then
    echo "  Total:      $(jq -r '.count // "n/a"' "$OUTPUT")"
    echo "  Errors:     $(jq -r '.errorCount // 0' "$OUTPUT")"
    echo "  RPS:        $(jq -r '.rps // "n/a"' "$OUTPUT")"
    echo "  Latency p50: $(jq -r '.latencies.p50 // "n/a"' "$OUTPUT")"
    echo "  Latency p90: $(jq -r '.latencies.p90 // "n/a"' "$OUTPUT")"
    echo "  Latency p99: $(jq -r '.latencies.p99 // "n/a"' "$OUTPUT")"
  else
    echo "  (Install jq for parsed summary)"
    echo "  Raw results: $OUTPUT"
  fi
else
  echo "WARNING: output file was not created"
fi
