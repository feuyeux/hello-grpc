#!/bin/bash
#
# test-rpc-modes.sh — Test all 4 gRPC RPC modes against each running server.
#
# Tests: unary (Talk), server-streaming (TalkOneAnswerMore),
#        client-streaming (TalkMoreAnswerOne), bidi (TalkBidirectional)
#
# Uses grpcurl for reflection-capable servers, or ghz with proto file.
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

# Check for grpcurl or ghz
if command -v grpcurl &>/dev/null; then
  CLIENT="grpcurl"
elif command -v ghz &>/dev/null; then
  CLIENT="ghz"
else
  echo "ERROR: neither grpcurl nor ghz found" >&2
  exit 1
fi

PASS=0
FAIL=0
RESULTS=()

for entry in "${SERVERS[@]}"; do
  IFS='|' read -r name host port <<< "$entry"
  address="${host}:${port}"
  echo ""
  echo "========================================"
  echo "  Testing RPC modes: $name ($address)"
  echo "========================================"

  for rpc in Talk TalkOneAnswerMore TalkMoreAnswerOne TalkBidirectional; do
    echo -n "  $rpc ... "
    case "$rpc" in
      Talk)
        DATA='{"data":"0","meta":"test"}'
        ;;
      TalkOneAnswerMore)
        DATA='{"data":"0,1,2","meta":"test"}'
        ;;
      TalkMoreAnswerOne)
        DATA='[{"data":"0","meta":"test"},{"data":"1","meta":"test"}]'
        ;;
      TalkBidirectional)
        DATA='[{"data":"0","meta":"test"},{"data":"1","meta":"test"}]'
        ;;
    esac

    if [[ "$CLIENT" == "grpcurl" ]]; then
      # Try with reflection first, fall back to proto file
      if grpcurl -plaintext -d "$DATA" "$address" "hello.LandingService/$rpc" >/dev/null 2>&1; then
        echo "PASS"
        PASS=$((PASS+1))
        RESULTS+=("$name/$rpc: PASS")
      elif grpcurl -plaintext -proto "$PROTO_FILE" -d "$DATA" "$address" "hello.LandingService/$rpc" >/dev/null 2>&1; then
        echo "PASS (proto)"
        PASS=$((PASS+1))
        RESULTS+=("$name/$rpc: PASS")
      else
        echo "FAIL"
        FAIL=$((FAIL+1))
        RESULTS+=("$name/$rpc: FAIL")
      fi
    else
      # Use ghz
      if ghz --insecure --proto "$PROTO_FILE" --call "hello.LandingService/$rpc" -d "$DATA" "$address" >/dev/null 2>&1; then
        echo "PASS"
        PASS=$((PASS+1))
        RESULTS+=("$name/$rpc: PASS")
      else
        echo "FAIL"
        FAIL=$((FAIL+1))
        RESULTS+=("$name/$rpc: FAIL")
      fi
    fi
  done
done

echo ""
echo "========================================"
echo "  RPC MODES SUMMARY: $PASS passed, $FAIL failed"
echo "========================================"
for r in "${RESULTS[@]}"; do echo "  $r"; done

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
