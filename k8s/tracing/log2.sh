#!/usr/bin/env bash
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit

USER_CONFIG=~/shop_config/ack_bj
alias k="kubectl --kubeconfig $USER_CONFIG"
MESH_CONFIG=~/shop_config/asm_bj
alias m="kubectl --kubeconfig $MESH_CONFIG"

server1_pod=$(k get pod -l app=grpc-server-deploy2 -n grpc-tracing -o jsonpath={.items..metadata.name})
k -n grpc-tracing logs $server1_pod -c grpc-server-deploy2 -f