#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e
echo "~~~ build grpc server dart ~~~"
mkdir -p hello-grpc-dart/bin
cp -R ../hello-grpc-dart/* hello-grpc-dart
ls -htl hello-grpc-dart
docker build -f grpc-dart.dockerfile --target server -t feuyeux/grpc_server_dart:1.0.0 .
echo

echo "~~~ build grpc client dart ~~~"
docker build -f grpc-dart.dockerfile --target client -t feuyeux/grpc_client_dart:1.0.0 .
rm -rf hello-grpc-dart
echo
