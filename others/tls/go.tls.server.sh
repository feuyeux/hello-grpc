#!/bin/bash
docker run --rm --name grpc_server_go -p 9996:9996 \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_server_go:1.0.0