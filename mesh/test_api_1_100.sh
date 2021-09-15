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

m apply -f grpc-vs-api-100.yaml
sleep 10s

echo "(talk from JAVA, talkOneAnswerMore from GOLANG, talkMoreAnswerOne from NODEJS, talkBidirectional from PYTHON)"
for i in {1..20}; do
  docker exec -e GRPC_SERVER="${INGRESS_IP}" -it "$client_node_container" node mesh_client.js
done
rm -rf mesh_result
for i in {1..10}; do
  docker exec -e GRPC_SERVER="${INGRESS_IP}" -it "$client_node_container" node mesh_client.js >> mesh_result
done
sort mesh_result | grep -v "^[[:space:]]*$"| uniq -c | sort -nrk1
rm -rf mesh_result