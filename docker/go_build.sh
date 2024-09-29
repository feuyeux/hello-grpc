#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

cd ../hello-grpc-go
sh init.sh
bash proto2go.sh

echo "~~~ build grpc server golang ~~~"
env GOOS=linux GOARCH=amd64 go build -o proto_server server/proto_server.go
mv proto_server ../docker/
cd ../docker
docker build -f go_grpc.dockerfile --target server -t feuyeux/grpc_server_go:1.0.0 .
rm -rf proto_server
echo

echo "~~~ build grpc client golang ~~~"
cd ../hello-grpc-go
export GO111MODULE="on"
env GOOS=linux GOARCH=amd64 go build -o proto_client client/proto_client.go
mv proto_client ../docker/
cd ../docker
docker build -f go_grpc.dockerfile --target client -t feuyeux/grpc_client_go:1.0.0 .
rm -rf proto_client
echo
