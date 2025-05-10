#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

# Enable TLS communication
export GRPC_HELLO_SECURE=Y
swift run HelloClient
