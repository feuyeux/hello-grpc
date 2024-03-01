#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

export GOROOT
GOROOT="$(brew --prefix golang)/libexec"
export GOPATH=$HOME/gopath
export PATH="$PATH:$GOPATH/bin"
#
export GOPROXY=https://mirrors.aliyun.com/goproxy/
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
echo "generate the messages"
protoc --go_out=. ./proto/landing.proto
echo "generate the services"
protoc --go-grpc_out="$(pwd)" ./proto/landing.proto
