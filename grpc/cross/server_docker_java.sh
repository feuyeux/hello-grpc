#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
 
docker run --rm --name grpc_server_java -p 9996:9996 \
feuyeux/grpc_server_java:1.0.0