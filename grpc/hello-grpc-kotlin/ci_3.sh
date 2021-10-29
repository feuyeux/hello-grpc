#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

# server1:8881
export GRPC_SERVER_PORT=8881
export GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0)
export GRPC_HELLO_BACKEND_PORT=8882
sh server_start.sh