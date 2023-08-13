#!/bin/bash
# shellcheck disable=SC2046

cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

sh docker/tools/clean_world.sh

# 1: kotlin|java|go|rust|tcp
# 2: kotlin|java|go|rust|tls
# 3: nodejs|csharp|python|c++|tcp
# 4: nodejs|csharp|python|c++|tls
# 0: ${2}|${3}|${4}|${5}|${6}
# default: java|java|java|java|tcp

if [[ "${1}" == "1" ]]; then
    client_lang="kotlin"
    server1_lang="rust"
    server2_lang="go"
    server3_lang="java"
    is_tls="N"
elif [[ "${1}" == "2" ]]; then
    client_lang="kotlin"
    server1_lang="java"
    server2_lang="go"
    server3_lang="rust"
    is_tls="Y"
elif [[ "${1}" == "3" ]]; then
    client_lang="node"
    server1_lang="python"
    server2_lang="csharp"
    server3_lang="cpp"
    is_tls="N"
elif [[ "${1}" == "4" ]]; then
    client_lang="python"
    server1_lang="node"
    server2_lang="csharp"
    server3_lang="cpp"
    is_tls="Y"
elif [[ "${1}" == "0" ]]; then
    is_tls=${6}
    client_lang=${2}
    server1_lang=${3}
    server2_lang=${4}
    server3_lang=${5}
else
    is_tls="N"
    client_lang="java"
    server1_lang="java"
    server2_lang="java"
    server3_lang="java"
fi
echo "is_tls:$is_tls c:$client_lang s1:$server1_lang s2:$server2_lang s3:$server3_lang"

echo "start server3:8883"
docker run --rm --name server3 -d \
    -p 8883:8883 \
    -e GRPC_SERVER_PORT=8883 \
    -e GRPC_HELLO_SECURE="${is_tls}" \
    feuyeux/grpc_server_"${server3_lang}":1.0.0
docker ps

echo "start server2:8882"
docker run --rm --name server2 -d \
    -p 8882:8882 \
    -e GRPC_SERVER_PORT=8882 \
    -e GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0) \
    -e GRPC_HELLO_BACKEND_PORT=8883 \
    -e GRPC_HELLO_SECURE="${is_tls}" \
    feuyeux/grpc_server_"${server2_lang}":1.0.0
docker ps

echo "start server1:8881"
docker run --rm --name server1 -d \
    -p 8881:8881 \
    -e GRPC_SERVER_PORT=8881 \
    -e GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0) \
    -e GRPC_HELLO_BACKEND_PORT=8882 \
    -e GRPC_HELLO_SECURE="${is_tls}" \
    feuyeux/grpc_server_"${server1_lang}":1.0.0
docker ps

sleep 5s

echo "start client"
docker run --rm --name grpc_client \
    -e GRPC_SERVER=$(ipconfig getifaddr en0) \
    -e GRPC_SERVER_PORT=8882 \
    -e GRPC_HELLO_SECURE="${is_tls}" \
    feuyeux/grpc_client_"${client_lang}":1.0.0

# sh docker/tools/clean_world.sh
