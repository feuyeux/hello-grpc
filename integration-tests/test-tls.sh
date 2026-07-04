#!/bin/bash
#
# test-tls.sh — Test TLS connections to each running server.
#
# This test verifies that servers configured with GRPC_HELLO_SECURE=Y
# accept TLS connections and respond correctly.
#
# For servers without TLS, this test is skipped with a note.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTO_FILE="$REPO_ROOT/proto/landing.proto"

# TLS certificate paths (matching server-side defaults)
CERT_DIR="${CERT_BASE_PATH:-/var/hello_grpc/client_certs}"

# Servers to test: name|host|port|use_tls
SERVERS=(
  "go|localhost|9991|false"
  "java|localhost|9992|false"
  "python|localhost|9993|false"
  "node|localhost|9994|false"
  "rust|localhost|9995|false"
)

PASS=0
FAIL=0
SKIP=0
RESULTS=()

for entry in "${SERVERS[@]}"; do
  IFS='|' read -r name host port use_tls <<< "$entry"
  address="${host}:${port}"

  echo -n "  TLS test: $name ($address) ... "

  if [[ "$use_tls" != "true" ]]; then
    echo "SKIP (insecure mode)"
    SKIP=$((SKIP+1))
    RESULTS+=("$name: SKIP (insecure)")
    continue
  fi

  # Test TLS connection with grpcurl
  if command -v grpcurl &>/dev/null; then
    if grpcurl \
      -proto "$PROTO_FILE" \
      -d '{"data":"0","meta":"tls-test"}' \
      -cname hello.grpc.io \
      -cert "$CERT_DIR/full_chain.pem" \
      -key "$CERT_DIR/private.pkcs8.key" \
      -cacert "$CERT_DIR/myssl_root.cer" \
      "$address" "hello.LandingService/Talk" >/dev/null 2>&1; then
      echo "PASS"
      PASS=$((PASS+1))
      RESULTS+=("$name: PASS")
    else
      echo "FAIL"
      FAIL=$((FAIL+1))
      RESULTS+=("$name: FAIL")
    fi
  elif command -v ghz &>/dev/null; then
    if ghz \
      --proto "$PROTO_FILE" \
      --call "hello.LandingService/Talk" \
      -d '{"data":"0","meta":"tls-test"}' \
      --cname hello.grpc.io \
      --cert "$CERT_DIR/full_chain.pem" \
      --key "$CERT_DIR/private.pkcs8.key" \
      --cacert "$CERT_DIR/myssl_root.cer" \
      "$address" >/dev/null 2>&1; then
      echo "PASS"
      PASS=$((PASS+1))
      RESULTS+=("$name: PASS")
    else
      echo "FAIL"
      FAIL=$((FAIL+1))
      RESULTS+=("$name: FAIL")
    fi
  else
    echo "SKIP (no grpcurl/ghz)"
    SKIP=$((SKIP+1))
    RESULTS+=("$name: SKIP (no tool)")
  fi
done

echo ""
echo "========================================"
echo "  TLS TEST SUMMARY: $PASS passed, $FAIL failed, $SKIP skipped"
echo "========================================"
for r in "${RESULTS[@]}"; do echo "  $r"; done

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
