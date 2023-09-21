#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export GO111MODULE="on"
export GOPATH=$GOPATH:${PWD}
export GRPC_SERVER=$(ipconfig getifaddr en0)
go run client/proto_client.go
