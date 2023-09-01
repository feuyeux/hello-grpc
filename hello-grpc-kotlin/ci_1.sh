#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

# server3:8883
export GRPC_SERVER_PORT=8883
sh server_start.sh