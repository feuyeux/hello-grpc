#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

# make
# export BASEDIR=$HOME/.local/bin/

# brew install protobuf
export BASEDIR=/usr/local/bin/

export PROTOC=$BASEDIR/protoc
export PLUGIN=protoc-gen-grpc=$BASEDIR/grpc_php_plugin

mkdir -p common/msg common/svc
$PROTOC --proto_path=proto \
    --php_out=common/msg \
    --grpc_out=generate_server:common/svc \
    --plugin=$PLUGIN proto/landing.proto
