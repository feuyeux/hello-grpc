#!/bin/bash
# shellcheck disable=SC2046

export server_lang=java
export client_lang=java
export is_tls=false

####
export discovery=etcd
host="$(ipconfig getifaddr en0)"
# host=192.168.0.105
export host
export discovery_endpoint=http://${host}:2379
http GET "${discovery_endpoint}/version"
sleep 2s
####
echo "start server"
docker run --rm --name grpc_server -d \
    -p 1888:1888 \
    -e GRPC_SERVER_PORT=1888 \
    -e GRPC_HELLO_SECURE="${is_tls}" \
    -e GRPC_SERVER="${host}" \
    -e GRPC_HELLO_DISCOVERY="${discovery}" \
    -e GRPC_HELLO_DISCOVERY_ENDPOINT="${discovery_endpoint}" \
    feuyeux/grpc_server_"${server_lang}":1.0.0
echo "===="
sleep 5s
echo "start client"
docker run --rm --name grpc_client \
    -e GRPC_SERVER="${host}" \
    -e GRPC_SERVER_PORT=1888 \
    -e GRPC_HELLO_SECURE="${is_tls}" \
    -e GRPC_HELLO_DISCOVERY="${discovery}" \
    -e GRPC_HELLO_DISCOVERY_ENDPOINT="${discovery_endpoint}" \
    feuyeux/grpc_client_"${client_lang}":1.0.0

echo "===="
sleep 5s
sh docker/tools/clean_world.sh
echo "done"
