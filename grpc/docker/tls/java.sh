#!/usr/bin/env bash
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)"
cd "$SCRIPT_PATH" || exit
# convert to pkcs#8
openssl pkcs8 -topk8 -nocrypt -in server_certs/private.key -out server_certs/private.pkcs8.key
openssl pkcs8 -topk8 -nocrypt -in client_certs/private.key -out client_certs/private.pkcs8.key