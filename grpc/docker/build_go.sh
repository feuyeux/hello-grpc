#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc server golang ~~~"
cd ../hello-grpc-go
export GO111MODULE="on"
env GOOS=linux GOARCH=amd64 go build -o proto_server server/proto_server.go
mv proto_server ../docker/
cd ../docker
docker build -f grpc-server-go.dockerfile -t feuyeux/grpc_server_go:1.0.0 .
rm -rf proto_server
echo

echo "~~~ build grpc client golang ~~~"
cd ../hello-grpc-go
export GO111MODULE="on"
env GOOS=linux GOARCH=amd64 go build -o proto_client client/proto_client.go
mv proto_client ../docker/
cd ../docker
docker build -f grpc-client-go.dockerfile -t feuyeux/grpc_client_go:1.0.0 .
rm -rf proto_client
echo
