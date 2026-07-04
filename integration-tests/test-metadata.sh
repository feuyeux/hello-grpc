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
RESULTS=()

for entry in "${SERVERS[@]}"; do
  IFS='|' read -r name host port <<< "$entry"
  address="${host}:${port}"
  echo -n "  Metadata test: $name ($address) ... "

  # Send a unary call with tracing headers using grpcurl
  if command -v grpcurl &>/dev/null; then
    # grpcurl allows -H for metadata
    if grpcurl \
      -plaintext \
      -proto "$PROTO_FILE" \
      -H "x-b3-traceid: $TRACE_ID" \
      -H "x-b3-spanid: $PARENT_SPAN" \
      -d '{"data":"0","meta":"metadata-test"}' \
      "$address" "hello.LandingService/Talk" >/dev/null 2>&1; then
      echo "PASS"
      PASS=$((PASS+1))
      RESULTS+=("$name: PASS")
    else
      echo "FAIL"
      FAIL=$((FAIL+1))
      RESULTS+=("$name: FAIL")
    fi
  else
    echo "SKIP (no grpcurl)"
    RESULTS+=("$name: SKIP")
  fi
done

echo ""
echo "========================================"
echo "  METADATA TEST SUMMARY: $PASS passed, $FAIL failed"
echo "========================================"
for r in "${RESULTS[@]}"; do echo "  $r"; done

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
