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

INGRESS_IP=$(k -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

docker stop $(docker ps -a -q) >/dev/null 2>&1
docker rm $(docker ps -a -q) >/dev/null 2>&1
docker run -d --name grpc_client_node -e GRPC_SERVER="${INGRESS_IP}" feuyeux/grpc_client_node:1.0.0 /bin/sleep 3650d
client_node_container=$(docker ps -q)

# echo "Test from pod:"
# client_node_pod=$(k get pod -l app=grpc-client-node -n grpc-tracing -o jsonpath={.items..metadata.name})
# k exec "$client_node_pod" -c grpc-client-node -n grpc-tracing -- node mesh_client.js grpc-server-svc1.grpc-tracing.svc.cluster.local 8888
# echo "Test from ingressgateway:"
# docker exec -it "$client_node_container" node mesh_client.js ${INGRESS_IP} 8888

echo "Test in a loop:"
for i in {1..100}; do
  docker exec -e GRPC_SERVER="${INGRESS_IP}" -it "$client_node_container" node mesh_client.js ${INGRESS_IP} 8888
done