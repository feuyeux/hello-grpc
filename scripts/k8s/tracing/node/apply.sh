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

sh ../docker/build_node.sh
docker push feuyeux/grpc_server_node:1.0.0

echo "Start to apply crd to grpc-tracing ..."
k delete namespace grpc-tracing >/dev/null 2>&1
sleep 5s
m delete namespace grpc-tracing >/dev/null 2>&1
sleep 5s

k create ns grpc-tracing
k label ns grpc-tracing istio-injection=enabled
m create ns grpc-tracing
m label ns grpc-tracing istio-injection=enabled

k apply -f grpc-tracing-sa.yaml
k apply -f grpc-server-node-1.yaml
k apply -f grpc-server-node-2.yaml
k apply -f grpc-server-node-3.yaml
m apply -f grpc-gw.yaml
m apply -f grpc-vs.yaml
k apply -f grpc-client-node.yaml
