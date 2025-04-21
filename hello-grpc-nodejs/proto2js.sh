#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
JS_PROTO_PATH=$(pwd)/common

echo "===="
npm config get registry
protoc --version
echo "JS_PROTO_PATH=${JS_PROTO_PATH}"
echo "===="

JS_PROTO_PATH=$(pwd)/common
protoc-gen-grpc \
--js_out=import_style=commonjs,binary:"${JS_PROTO_PATH}" \
--grpc_out=grpc_js:"${JS_PROTO_PATH}" \
--proto_path ./proto \
./proto/landing.proto
