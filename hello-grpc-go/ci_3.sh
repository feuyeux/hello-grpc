#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

# server1:8881
if [[ "${1}" == "c" ]]; then
    docker run --rm --name server1 \
        -p 8881:8881 \
        -e GRPC_SERVER_PORT=8881 \
        -e GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0) \
        -e GRPC_HELLO_BACKEND_PORT=8882 \
        -e GRPC_HELLO_SECURE="Y" \
        feuyeux/grpc_server_go:1.0.0
else
    export GRPC_SERVER_PORT=8881
    export GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0)
    export GRPC_HELLO_BACKEND_PORT=8882
    sh server_start.sh
fi
