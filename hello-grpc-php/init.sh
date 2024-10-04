#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

if [[ "$OSTYPE" == "msys" ]]; then
    echo "Build on Windows"
    export GRPC_SRC=/d/coding/grpc
    # bazel output
    export PROTOC=$GRPC_SRC/bazel-bin/external/com_google_protobuf/protoc.exe
    export PLUGIN=$GRPC_SRC/bazel-bin/src/compiler/grpc_php_plugin.exe
    if [[ ! -f "$PLUGIN" ]]; then
        cd $GRPC_SRC
        git checkout v1.66.2
        # bazel build
        bazel build @com_google_protobuf//:protoc && bazel build src/compiler:grpc_php_plugin
    fi
else
    # Unix-like 系统
    export BASEDIR="/usr/local/bin/"
    export PROTOC=$BASEDIR/protoc
    export PLUGIN=protoc-gen-grpc=$BASEDIR/grpc_php_plugin
fi

mkdir -p common/msg common/svc
$PROTOC --proto_path=proto \
    --php_out=common/msg \
    --grpc_out=generate_server:common/svc \
    --plugin="$PLUGIN" proto/landing.proto
