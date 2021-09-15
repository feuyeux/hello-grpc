#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export PATH="$PATH:$(go env GOPATH)/bin"
rm -rf "${go_proto_path}/common"
export OUTPUT_FILE=$(pwd)
export DIR_OF_PROTO_FILE=$(pwd)/proto
export PROTO_FILE=landing.proto
protoc --proto_path="$DIR_OF_PROTO_FILE" --go_out=plugins=grpc:"$OUTPUT_FILE" "$PROTO_FILE"