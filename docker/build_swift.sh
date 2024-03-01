#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc server swift ~~~"
rm -rf hello-grpc-swift
mkdir hello-grpc-swift
cp -r ../hello-grpc-swift/* hello-grpc-swift/
# docker build -f grpc-swift.dockerfile --target builder -t feuyeux/grpc_swift:1.0.0 .
#
docker build -f grpc-swift.dockerfile --target server -t feuyeux/grpc_server_swift:1.0.0 .
echo
echo "~~~ build grpc client swift ~~~"
docker build -f grpc-swift.dockerfile --target client -t feuyeux/grpc_client_swift:1.0.0 .
rm -rf hello-grpc-swift/
echo
