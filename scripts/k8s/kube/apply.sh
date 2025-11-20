#!/usr/bin/env bash
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit

echo "Start to apply crd to grpc-best ..."
USER_CONFIG=~/shop_config/ack_bj
alias k="kubectl --kubeconfig $USER_CONFIG"

# k delete namespace grpc-best >/dev/null 2>&1
# sleep 5s
k create ns grpc-best >/dev/null 2>&1
k label ns grpc-best istio-injection=enabled >/dev/null 2>&1

k apply -f grpc-sa.yaml
k apply -f grpc-svc.yaml
k apply -f deployment/grpc-server-java.yaml
k apply -f deployment/grpc-server-python.yaml
k apply -f deployment/grpc-server-go.yaml
k apply -f deployment/grpc-server-node.yaml
k apply -f deployment/grpc-server-rust.yaml
k apply -f deployment/grpc-client-java.yaml
k apply -f deployment/grpc-client-python.yaml
k apply -f deployment/grpc-client-go.yaml
k apply -f deployment/grpc-client-node.yaml
k apply -f deployment/grpc-client-rust.yaml