#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

# client
if [[ "${1}" == "c" ]]; then
    docker run --rm --name grpc_client \
        -e GRPC_SERVER=$(ipconfig getifaddr en0) \
        -e GRPC_SERVER_PORT=8881 \
        feuyeux/grpc_client_python:1.0.0
    sh ../docker/tools/clean_world.sh
else
    export GRPC_SERVER=$(ipconfig getifaddr en0)
    export GRPC_SERVER_PORT=8881
    #export GRPC_HELLO_SECURE="Y"
    sh client_start.sh
fi