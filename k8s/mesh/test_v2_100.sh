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

echo "start local docker container..."
docker stop $(docker ps -a -q) >/dev/null 2>&1
docker rm $(docker ps -a -q) >/dev/null 2>&1
docker run -d --name grpc_client_node -e GRPC_SERVER="${INGRESS_IP}" feuyeux/grpc_client_node:1.0.0 /bin/sleep 3650d
client_node_container=$(docker ps -q)

echo "==== Test v2 100% (4 api from GOLANG) ===="
m apply -f grpc-vs-v2-100.yaml
sleep 10s
echo "warm up ... "
for i in {1..10}; do
  docker exec -e GRPC_SERVER="${INGRESS_IP}" -it "$client_node_container" node header_client.js >/dev/null 2>&1
done
rm -rf mesh_result
echo "testing ... "
for i in {1..10}; do
  docker exec -e GRPC_SERVER="${INGRESS_IP}" -it "$client_node_container" node header_client.js >> mesh_result
done

sort mesh_result | grep -v "^[[:space:]]*$" | uniq -c | sort -nrk1
rm -rf mesh_result