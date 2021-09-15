#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc server rust ~~~"
cd ../hello-grpc-rust

CROSS_COMPILE=x86_64-linux-musl-gcc cargo build --release --bin proto-server --target=x86_64-unknown-linux-musl
mv target/x86_64-unknown-linux-musl/release/proto-server ../docker/
cd ../docker
echo "build server image"
docker build -f grpc-server-rust.dockerfile -t feuyeux/grpc_server_rust:1.0.0 .
rm -rf proto-server
echo

echo "~~~ build grpc client rust ~~~"
cd ../hello-grpc-rust
CROSS_COMPILE=x86_64-linux-musl-gcc cargo build --release --bin proto-client --target=x86_64-unknown-linux-musl
mv target/x86_64-unknown-linux-musl/release/proto-client ../docker/
cd ../docker
echo "build client image"
docker build -f grpc-client-rust.dockerfile -t feuyeux/grpc_client_rust:1.0.0 .
rm -rf proto-client
echo