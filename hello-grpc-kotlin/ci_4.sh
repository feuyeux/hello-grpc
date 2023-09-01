#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

# client
export GRPC_SERVER=$(ipconfig getifaddr en0)
export GRPC_SERVER_PORT=8881
sh client_start.sh
