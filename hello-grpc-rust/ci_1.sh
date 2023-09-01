#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e
# server3:8883
if [[ "${1}" == "c" ]]; then
    sh ../docker/tools/clean_world.sh
    docker run --rm --name server3 \
        -p 8883:8883 \
        -e GRPC_SERVER_PORT=8883 \
        feuyeux/grpc_server_rust:1.0.0
else
    export GRPC_SERVER_PORT=8883
    # export GRPC_HELLO_SECURE="Y"
    sh server_start.sh
fi
