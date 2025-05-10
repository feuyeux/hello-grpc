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
        git submodule update --init --recursive
        echo "bazel build"
        bazel clean --expunge
        bazel build @com_google_protobuf//:protoc
        bazel build src/compiler:grpc_php_plugin
    fi
else
    # Unix-like 系统
    export PROTOC=$(which protoc)
    # Check if grpc_php_plugin is in PATH
    if which grpc_php_plugin > /dev/null; then
        export PLUGIN="protoc-gen-grpc=$(which grpc_php_plugin)"
    elif [ -f "/opt/homebrew/bin/grpc_php_plugin" ]; then
        export PLUGIN="protoc-gen-grpc=/opt/homebrew/bin/grpc_php_plugin"
    elif [ -f "/usr/local/bin/grpc_php_plugin" ]; then
        export PLUGIN="protoc-gen-grpc=/usr/local/bin/grpc_php_plugin"
    else
        echo "Error: grpc_php_plugin not found. Please install it using:"
        echo "brew install grpc"
        exit 1
    fi
fi

mkdir -p common/msg common/svc
$PROTOC --proto_path=../proto \
    --php_out=common/msg \
    --grpc_out=generate_server:common/svc \
    --plugin="$PLUGIN" ../proto/landing.proto
