#!/bin/bash
#
# test-metadata.sh — Test gRPC metadata (header) propagation.
#
# Sends requests with custom tracing headers and verifies that
# the server receives and logs them. This validates the A6
# metadata propagation feature across languages.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTO_FILE="$REPO_ROOT/proto/landing.proto"

# Servers to test: name|host|port
SERVERS=(
  "go|localhost|9991"
  "java|localhost|9992"
  "python|localhost|9993"
  "node|localhost|9994"
  "rust|localhost|9995"
)

# Tracing headers to send
TRACE_ID="test-trace-$(date +%s)"
PARENT_SPAN="test-span-001"

PASS=0
FAIL=0
SKIP=0
RESULTS=()

# Map server name to docker-compose service name
service_name() {
  case "$1" in
    go) echo "go-server" ;;
    java) echo "java-server" ;;
    python) echo "python-server" ;;
    node) echo "node-server" ;;
    rust) echo "rust-server" ;;
    *) echo "$1-server" ;;
  esac
}

for entry in "${SERVERS[@]}"; do
  IFS='|' read -r name host port <<< "$entry"
  address="${host}:${port}"
  echo -n "  Metadata test: $name ($address) ... "

  if ! command -v grpcurl &>/dev/null; then
    echo "SKIP (no grpcurl)"
    SKIP=$((SKIP+1))
    RESULTS+=("$name: SKIP")
    continue
  fi

  # Send a unary call with tracing headers using grpcurl
  if ! grpcurl \
    -plaintext \
    -proto "$PROTO_FILE" \
    -H "x-b3-traceid: $TRACE_ID" \
    -H "x-b3-spanid: $PARENT_SPAN" \
    -d '{"data":"0","meta":"metadata-test"}' \
    "$address" "hello.LandingService/Talk" >/dev/null 2>&1; then
    echo "FAIL (RPC error)"
    FAIL=$((FAIL+1))
    RESULTS+=("$name: FAIL (RPC error)")
    continue
  fi

  # Verify the server actually received and logged the tracing headers.
  # A small delay lets the server flush logs before we inspect them.
  sleep 1
  svc=$(service_name "$name")
  if docker-compose -f "$SCRIPT_DIR/docker-compose.yml" logs --tail=100 "$svc" 2>/dev/null | grep -q "$TRACE_ID"; then
    echo "PASS (headers verified in server logs)"
    PASS=$((PASS+1))
    RESULTS+=("$name: PASS")
  else
    echo "FAIL (RPC ok but headers not found in server logs)"
    FAIL=$((FAIL+1))
    RESULTS+=("$name: FAIL (no header verification)")
  fi
done

echo ""
echo "========================================"
echo "  METADATA TEST SUMMARY: $PASS passed, $FAIL failed, $SKIP skipped"
echo "========================================"
for r in "${RESULTS[@]}"; do echo "  $r"; done

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
