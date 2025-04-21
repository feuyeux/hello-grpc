#!/bin/bash
# shellcheck disable=SC2046
echo "CLIENT_NAME=$CLIENT_NAME CLIENT_IMG=$CLIENT_IMG"

docker run --rm --name "$CLIENT_NAME" -e GRPC_SERVER=host.docker.internal "$CLIENT_IMG"
# docker run --rm --name "$CLIENT_NAME" -e GRPC_SERVER=$(ipconfig getifaddr en0) "$CLIENT_IMG"
