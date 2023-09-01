#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e
echo "~~~ build grpc server node ~~~"
mkdir -p hello-grpc-nodejs
cp ../hello-grpc-nodejs/proto_server.js hello-grpc-nodejs
cp ../hello-grpc-nodejs/package.json hello-grpc-nodejs
cp -R ../hello-grpc-nodejs/common hello-grpc-nodejs
cp -R ../proto hello-grpc-nodejs
docker build -f grpc-server-node.dockerfile -t feuyeux/grpc_server_node:1.0.0 .
rm -rf hello-grpc-nodejs/proto_server.js
echo

echo "~~~ build grpc client node ~~~"
cp ../hello-grpc-nodejs/*_client.js hello-grpc-nodejs
docker build -f grpc-client-node.dockerfile -t feuyeux/grpc_client_node:1.0.0 .
rm -rf hello-grpc-nodejs
echo
