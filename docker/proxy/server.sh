#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

lang="${1:-java}"
docker run --rm --name grpc_server \
    -p 8883:8883 \
    -e GRPC_SERVER_PORT=8883 \
    -e GRPC_HELLO_SECURE="Y" \
    feuyeux/grpc_server_${lang}:1.0.0
