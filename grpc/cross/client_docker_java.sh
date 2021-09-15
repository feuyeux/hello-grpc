#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
 
docker run --rm --name grpc_client_java -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_java:1.0.0 java -jar /grpc-client.jar