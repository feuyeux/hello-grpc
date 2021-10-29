#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc rust ~~~"
cd ..
cp -r hello-grpc-rust docker/
cd docker
docker build -f grpc-rust.dockerfile --target build -t feuyeux/grpc_rust:1.0.0 .
docker build -f grpc-rust.dockerfile --target server -t feuyeux/grpc_server_rust:1.0.0 .
docker build -f grpc-rust.dockerfile --target client -t feuyeux/grpc_client_rust:1.0.0 .
rm -rf hello-grpc-rust
echo

# docker run --rm -it --entrypoint=sh docker.io/feuyeux/grpc_rust:1.0.0