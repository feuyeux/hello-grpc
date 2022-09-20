#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export GOPROXY=https://mirrors.aliyun.com/goproxy/
go mod tidy
#brew install protobuf
#brew install protoc-gen-go
go install github.com/golang/protobuf/protoc-gen-go