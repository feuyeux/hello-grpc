#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

docker images | grep rust

echo "~~~ build grpc rust ~~~"
cd ..
cp -r hello-grpc-rust docker/
cd docker
# docker build --cpu-shares=5120 --memory=4g -f rust_grpc.dockerfile --target build -t feuyeux/grpc_rust:1.0.0 .
docker build -f rust_grpc.dockerfile --target server -t feuyeux/grpc_server_rust:1.0.0 .
docker build -f rust_grpc.dockerfile --target client -t feuyeux/grpc_client_rust:1.0.0 .
rm -rf hello-grpc-rust
echo

# docker run --rm -it --entrypoint=sh docker.io/feuyeux/grpc_rust:1.0.0
