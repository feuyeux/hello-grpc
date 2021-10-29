#!/bin/bash
docker run --rm --name server1 -d \
    -p 8881:8881 \
    -e GRPC_SERVER_PORT=8881 \
    -e GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0) \
    -e GRPC_HELLO_BACKEND_PORT=8882 \
    -e GRPC_HELLO_SECURE=Y \
    feuyeux/grpc_server_java:1.0.0