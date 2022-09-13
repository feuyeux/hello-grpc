#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
rm -rf common
mkdir common
protoc --cpp_out=./common landing.proto
protoc --grpc_out=./common --plugin=protoc-gen-grpc=/usr/local/bin/grpc_cpp_plugin landing.proto