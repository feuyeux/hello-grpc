#!/bin/bash
# shellcheck disable=SC2046
echo "CLIENT_NAME=$CLIENT_NAME CLIENT_IMG=$CLIENT_IMG"

docker run --rm --name "$CLIENT_NAME" \
    -e GRPC_SERVER=host.docker.internal \
    -e GRPC_HELLO_SECURE=Y \
    "$CLIENT_IMG"

# docker run --rm --name "$CLIENT_NAME" \
#     -e GRPC_SERVER=$(ipconfig getifaddr en0) \
#     -e GRPC_HELLO_SECURE=Y \
#     "$CLIENT_IMG"
