#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc swift ~~~"
# docker images | grep swift
#docker pull swift:6.0.1
#docker pull swift:6.0.1-slim

rm -rf hello-grpc-swift
mkdir hello-grpc-swift
cp -r ../hello-grpc-swift/* hello-grpc-swift/
# for cache the working layers
docker build -f swift_grpc.dockerfile --target builder -t feuyeux/grpc_swift:1.0.0 .
echo
echo "~~~ build grpc server swift ~~~"
docker build -f swift_grpc.dockerfile --target server -t feuyeux/grpc_server_swift:1.0.0 .
echo
echo "~~~ build grpc client swift ~~~"
docker build -f swift_grpc.dockerfile --target client -t feuyeux/grpc_client_swift:1.0.0 .
rm -rf hello-grpc-swift/
echo
