#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
sh ../docker/tools/clean_world.sh
docker ps -a
docker run --rm --name server2 -d \
    -p 8882:8882 \
    -e GRPC_SERVER_PORT=8882 \
    -e GRPC_HELLO_SECURE=Y \
    feuyeux/grpc_server_java:1.0.0