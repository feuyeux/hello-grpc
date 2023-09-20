#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

export PROTOC=$HOME/.local/bin/protoc
export PLUGIN=protoc-gen-grpc=$HOME/.local/bin/grpc_php_plugin

mkdir -p common/msg common/svc
$PROTOC --proto_path=proto \
       --php_out=common/msg \
       --grpc_out=generate_server:common/svc \
       --plugin=$PLUGIN proto/landing.proto
