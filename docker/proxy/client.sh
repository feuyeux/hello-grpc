#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

lang="${1:-java}"
docker run --rm --name grpc_client \
    -e GRPC_SERVER=$(ipconfig getifaddr en0) \
    -e GRPC_SERVER_PORT=8882 \
    -e GRPC_HELLO_SECURE="Y" \
    feuyeux/grpc_client_${lang}:1.0.0