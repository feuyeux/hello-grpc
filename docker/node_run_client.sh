#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
export CLIENT_NAME=grpc_client_node
export CLIENT_IMG=feuyeux/$CLIENT_NAME:1.0.0
# if there's first argument, it's secure, otherwise insecure
if [ "$1" = "secure" ]; then
    sh run_tls_client.sh
else
    sh run_insecure_client.sh
fi
