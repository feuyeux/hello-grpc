#!/usr/bin/env bash
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit

USER_CONFIG=~/shop_config/ack_bj
MESH_CONFIG=~/shop_config/asm_bj
alias k="kubectl --kubeconfig $USER_CONFIG"
alias m="kubectl --kubeconfig $MESH_CONFIG"

client_java_pod=$(k get pod -l app=grpc-client-java -n grpc-best -o jsonpath={.items..metadata.name})
client_go_pod=$(k get pod -l app=grpc-client-go -n grpc-best -o jsonpath={.items..metadata.name})
client_node_pod=$(k get pod -l app=grpc-client-node -n grpc-best -o jsonpath={.items..metadata.name})
client_python_pod=$(k get pod -l app=grpc-client-python -n grpc-best -o jsonpath={.items..metadata.name})
client_rust_pod=$(k get pod -l app=grpc-client-rust -n grpc-best -o jsonpath={.items..metadata.name})

echo "Test Java Client"
k exec "$client_java_pod" -c grpc-client-java -n grpc-best -- java -jar /grpc-client.jar
echo
echo "Test Golang Client"
k exec "$client_go_pod" -c grpc-client-go -n grpc-best -- ./grpc-client
echo
echo "Test NodeJs Client"
k exec "$client_node_pod" -c grpc-client-node -n grpc-best -- node proto_client.js
echo
echo "Test Python Client"
k exec "$client_python_pod" -c grpc-client-python -n grpc-best -- sh /grpc-client/client_start.sh
echo
echo "Test Rust Client"
k exec "$client_rust_pod" -c grpc-client-rust -n grpc-best -- ./grpc-client
echo

echo "Test in loop"
rm -rf kube_result
for ((i = 1; i <= 100; i++)); do
  k exec "$client_node_pod" -c grpc-client-node -n grpc-best -- node kube_client.js >> kube_result
done
sort kube_result | grep -v "^[[:space:]]*$" | uniq -c | sort -nrk1