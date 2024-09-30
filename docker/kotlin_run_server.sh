#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
export SERVER_NAME=grpc_server_kotlin
export SERVER_IMG=feuyeux/$SERVER_NAME:1.0.0
# if there's first argument, it's secure, otherwise insecure
if [ "$1" = "secure" ]; then
    sh run_tls_server.sh
else
    sh run_insecure_server.sh
fi
