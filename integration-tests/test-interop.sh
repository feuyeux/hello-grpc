#!/usr/bin/env bash
set -euo pipefail

SERVERS="go,java,python,nodejs,rust"
CLIENTS="go,java,python,nodejs,rust"
OUTPUT="interop-results.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--servers) SERVERS="$2"; shift 2 ;;
    -c|--clients) CLIENTS="$2"; shift 2 ;;
    -o|--output) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

IFS=',' read -r -a server_list <<< "$SERVERS"
IFS=',' read -r -a client_list <<< "$CLIENTS"
tmp_results=$(mktemp)
trap 'rm -f "$tmp_results"; docker rm -f grpc_interop_server >/dev/null 2>&1 || true' EXIT

image_name() {
  local language=$1 component=$2
  if [[ "$language" == nodejs ]]; then
    echo "feuyeux/grpc_${component}_node:1.0.0"
  else
    echo "feuyeux/grpc_${component}_${language}:1.0.0"
  fi
}

failures=0
for server in "${server_list[@]}"; do
  docker rm -f grpc_interop_server >/dev/null 2>&1 || true
  docker run -d --rm --name grpc_interop_server -p 9996:9996 "$(image_name "$server" server)" >/dev/null

  ready=0
  for _ in $(seq 1 30); do
    if (echo >/dev/tcp/127.0.0.1/9996) 2>/dev/null; then ready=1; break; fi
    sleep 1
  done

  for client in "${client_list[@]}"; do
    status=failed
    log_file=$(mktemp)
    if [[ $ready -eq 1 ]] && timeout 60 docker run --rm \
      --add-host=host.docker.internal:host-gateway \
      -e GRPC_SERVER=host.docker.internal \
      "$(image_name "$client" client)" >"$log_file" 2>&1; then
      if ! grep -qiE 'fatal|panic|unhandled|connection refused|deadline exceeded' "$log_file"; then
        status=passed
      fi
    fi
    if [[ "$status" != passed ]]; then failures=$((failures+1)); fi
    printf '%s\t%s\t%s\n' "$server" "$client" "$status" >> "$tmp_results"
    rm -f "$log_file"
  done
done

{
  echo '{"results":['
  first=1
  while IFS=$'\t' read -r server client status; do
    if [[ $first -eq 0 ]]; then echo ','; fi
    first=0
    printf '{"server":"%s","client":"%s","status":"%s"}' "$server" "$client" "$status"
  done < "$tmp_results"
  echo ']}'
} > "$OUTPUT"

exit "$failures"
