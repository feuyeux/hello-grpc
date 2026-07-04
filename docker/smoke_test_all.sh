#!/bin/bash
#
# smoke_test_all.sh — Run same-language smoke tests for all 12 gRPC implementations.
#
# Usage:
#   ./smoke_test_all.sh              # Same-language tests only (default)
#   ./smoke_test_all.sh --interop    # Also run cross-language interop tests
#
set -u
cd "$(dirname "$0")"

RUN_INTEROP=false
for arg in "$@"; do
  case "$arg" in
    --interop) RUN_INTEROP=true ;;
    *) echo "Unknown option: $arg"; echo "Usage: $0 [--interop]"; exit 1 ;;
  esac
done

LANGS=(cpp rust java go csharp python nodejs dart kotlin swift php ts)
RESULTS=()
LOG_DIR=smoke_logs
mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.log

PASS=0
FAIL=0

img_name() { local lang="$1" comp="$2"; [[ "$lang" == "nodejs" ]] && echo "feuyeux/grpc_${comp}_node:1.0.0" || echo "feuyeux/grpc_${comp}_${lang}:1.0.0"; }
ctr_name() { local lang="$1" comp="$2"; [[ "$lang" == "nodejs" ]] && echo "grpc_${comp}_node" || echo "grpc_${comp}_${lang}"; }

for lang in "${LANGS[@]}"; do
  docker rm -f "$(ctr_name "$lang" server)" "$(ctr_name "$lang" client)" 2>/dev/null || true
done

fuser -k 9996/tcp 2>/dev/null || true

for lang in "${LANGS[@]}"; do
  SERVER_IMG=$(img_name "$lang" server)
  CLIENT_IMG=$(img_name "$lang" client)
  SVR_CTR=$(ctr_name "$lang" server)
  CLI_CTR=$(ctr_name "$lang" client)
  SVR_LOG="$LOG_DIR/${lang}_server.log"
  CLI_LOG="$LOG_DIR/${lang}_client.log"
  PASS_FILE="$LOG_DIR/${lang}.pass"

  echo "================================================================"
  echo "[$lang] server=$SERVER_IMG client=$CLIENT_IMG"
  echo "================================================================"

  if ! docker run -d --rm --name "$SVR_CTR" -p 9996:9996 "$SERVER_IMG" > "$LOG_DIR/${lang}_server.cid" 2>/dev/null; then
    echo "  RESULT: FAIL  (server failed to start)"
    RESULTS+=("$lang: FAIL (server start)")
    FAIL=$((FAIL+1))
    continue
  fi

  ok=0
  for i in $(seq 1 30); do
    if (echo > /dev/tcp/127.0.0.1/9996) 2>/dev/null; then ok=1; echo "  port :9996 up after ${i}s"; break; fi
    sleep 1
  done
  if [[ $ok -eq 0 ]]; then
    echo "  RESULT: FAIL  (port 9996 never opened)"
    docker logs "$SVR_CTR" > "$SVR_LOG" 2>&1 || true
    docker rm -f "$SVR_CTR" 2>/dev/null || true
    RESULTS+=("$lang: FAIL (port)")
    FAIL=$((FAIL+1))
    continue
  fi

  cli_exit=0
  if [[ "$lang" == "swift" ]]; then
    timeout 60 docker run --rm --name "$CLI_CTR" --network="host" -e GRPC_SERVER=127.0.0.1 "$CLIENT_IMG" > "$CLI_LOG" 2>&1 || cli_exit=$?
  else
    timeout 60 docker run --rm --name "$CLI_CTR" -e GRPC_SERVER=host.docker.internal "$CLIENT_IMG" > "$CLI_LOG" 2>&1 || cli_exit=$?
  fi

  docker logs "$SVR_CTR" > "$SVR_LOG" 2>&1 || true
  docker rm -f "$SVR_CTR" 2>/dev/null || true

  reason=""
  if [[ $cli_exit -ne 0 ]]; then
    reason="client exit=$cli_exit"
  elif ! grep -qiE "All gRPC calls completed successfully|completed successfully|bidirectional stream completed|client execution completed|all calls completed|completed.*gRPC" "$CLI_LOG"; then
    if grep -qiE "fatal|panic|unhandled|connection refused|deadline exceeded" "$CLI_LOG"; then
      reason="client log shows errors"
    elif ! grep -qE "data=|Received|Response|response" "$CLI_LOG"; then
      reason="no success marker in client log"
    fi
  fi

  if [[ -z "$reason" ]]; then
    echo "  RESULT: PASS"
    RESULTS+=("$lang: PASS")
    PASS=$((PASS+1))
    touch "$PASS_FILE"
  else
    echo "  RESULT: FAIL  ($reason)"
    RESULTS+=("$lang: FAIL ($reason)")
    FAIL=$((FAIL+1))
  fi
done

echo
echo "================================================================"
echo "SUMMARY: $PASS passed, $FAIL failed (of ${#LANGS[@]})"
echo "================================================================"
for r in "${RESULTS[@]}"; do echo "  $r"; done

# Cross-language interop tests (optional, enabled with --interop)
if [[ "$RUN_INTEROP" == "true" ]]; then
  echo
  echo "================================================================"
  echo "  Cross-Language Interop Tests"
  echo "================================================================"
  INTEROP_SCRIPT="../integration-tests/test-interop.sh"
  if [[ -x "$INTEROP_SCRIPT" ]]; then
    "$INTEROP_SCRIPT" -s go,java,python -c go,java,python -o "$LOG_DIR/interop-results.json" || true
  else
    echo "  SKIP: $INTEROP_SCRIPT not found or not executable"
  fi
fi
