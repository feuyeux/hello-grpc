#!/usr/bin/env bash
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit

echo "Start to apply crd to grpc-best ..."
MESH_CONFIG=~/shop_config/asm_bj
alias m="kubectl --kubeconfig $MESH_CONFIG"

m delete namespace grpc-best >/dev/null 2>&1
sleep 5s
m create ns grpc-best
m label ns grpc-best istio-injection=enabled

m apply -f grpc-gw.yaml
m apply -f grpc-dr.yaml