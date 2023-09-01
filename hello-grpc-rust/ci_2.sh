#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

# server2:8882
if [[ "${1}" == "c" ]]; then
    docker run --rm --name server2 \
        -p 8882:8882 \
        -e GRPC_SERVER_PORT=8882 \
        -e GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0) \
        -e GRPC_HELLO_BACKEND_PORT=8883 \
        feuyeux/grpc_server_rust:1.0.0
else
    export GRPC_SERVER_PORT=8882
    export GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0)
    export GRPC_HELLO_BACKEND_PORT=8883
    # export GRPC_HELLO_SECURE="Y"
    sh server_start.sh
fi
