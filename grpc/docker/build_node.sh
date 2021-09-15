#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc server node ~~~"
mkdir -p node
cp ../hello-grpc-nodejs/proto_server.js node
cp ../hello-grpc-nodejs/package.json node
cp -R ../hello-grpc-nodejs/common node
cp -R ../proto node
docker build -f grpc-server-node.dockerfile -t feuyeux/grpc_server_node:1.0.0 .
rm -rf node/proto_server.js
echo

echo "~~~ build grpc client node ~~~"
cp ../hello-grpc-nodejs/*_client.js node
docker build -f grpc-client-node.dockerfile -t feuyeux/grpc_client_node:1.0.0 .
rm -rf node 
echo