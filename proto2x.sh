#!/bin/bash
# Unified script to generate gRPC code from proto files for different languages
# Usage: ./proto2x.sh [language]
# Supported languages: go, js, py, swift, ts, dart, all

cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

# Check if language argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: ./proto2x.sh [language]"
    echo "Supported languages: go, js, py, swift, ts, dart, all"
    exit 1
fi

LANGUAGE=$1
PROTO_DIR=$(pwd)/proto

echo "==== Generating gRPC code for $LANGUAGE from proto files ===="
echo "Proto directory: $PROTO_DIR"

# Function to generate Go gRPC code
generate_go() {
    echo "Generating Go gRPC code..."
    cd hello-grpc-go || exit

    export GOROOT=$(go env GOROOT)
    export GOPATH=$(go env GOPATH)
    echo "GOROOT=$GOROOT GOPATH=$GOPATH"
    export PATH="$PATH:$GOPATH/bin:/go/bin"

    PROTOC_VERSION=$(protoc --version)
    if [ -z "$PROTOC_VERSION" ]; then
        echo "install protoc firstly, see doc/proto.md"
        exit 1
    else
        echo "Protoc version: $PROTOC_VERSION"
    fi

    # Install the protoc plugins if they don't exist
    if ! command -v protoc-gen-go &>/dev/null; then
        echo "Installing protoc-gen-go..."
        export GOPROXY=https://mirrors.aliyun.com/goproxy/
        go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
    else
        echo "protoc-gen-go is already installed."
    fi

    if ! command -v protoc-gen-go-grpc &>/dev/null; then
        echo "Installing protoc-gen-go-grpc..."
        export GOPROXY=https://mirrors.aliyun.com/goproxy/
        go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
    else
        echo "protoc-gen-go-grpc is already installed."
    fi

    # For debugging purposes, check if the plugins are in PATH
    which protoc-gen-go || echo "protoc-gen-go not found in PATH"
    which protoc-gen-go-grpc || echo "protoc-gen-go-grpc not found in PATH"

    echo "generate the messages"
    protoc --proto_path="${PROTO_DIR}" --go_out=. "${PROTO_DIR}/landing.proto"
    echo "generate the services"
    protoc --proto_path="${PROTO_DIR}" --go-grpc_out=. "${PROTO_DIR}/landing.proto"

    cd ..
    echo "Go gRPC code generation completed"
}

# Function to generate JavaScript gRPC code
generate_js() {
    echo "Generating JavaScript gRPC code..."
    cd hello-grpc-nodejs || exit

    JS_PROTO_PATH=$(pwd)/common
    echo "===="
    npm config get registry
    protoc --version
    echo "JS_PROTO_PATH=${JS_PROTO_PATH}"
    echo "===="

    protoc-gen-grpc \
        --js_out=import_style=commonjs,binary:"${JS_PROTO_PATH}" \
        --grpc_out=grpc_js:"${JS_PROTO_PATH}" \
        --proto_path ../proto \
        ../proto/landing.proto

    cd ..
    echo "JavaScript gRPC code generation completed"
}

# Function to generate Python gRPC code
generate_py() {
    echo "Generating Python gRPC code..."
    cd hello-grpc-python || exit

    export proto_file_name="landing"
    export proto_gen_name=${proto_file_name}_pb2
    rm -f conn/${proto_gen_name}*

    # grpcio-tools
    export tools_version=$(python -m grpc.tools.protoc --version | cut -d' ' -f2)
    alias protoc=protoc"${tools_version}"
    echo "protoc version:$(protoc --version | cut -d' ' -f2);tools version: ${tools_version}"

    # generate python code to conn folder
    export proto_gen_path="$(pwd)/${proto_gen_name}"
    python -m grpc.tools.protoc \
        --proto_path="$(pwd)/../proto" \
        --python_out=conn \
        --pyi_out=conn \
        --grpc_python_out=conn \
        "$(pwd)/../proto/${proto_file_name}.proto"
    sed -i "s/landing_pb2/conn.landing_pb2/g" conn/${proto_gen_name}_grpc.py

    cd ..
    echo "Python gRPC code generation completed"
}

# Function to generate Swift gRPC code
generate_swift() {
    echo "Generating Swift gRPC code..."
    cd hello-grpc-swift || exit

    cd Sources/Common || exit

    protoc ../../../proto/landing.proto \
        --plugin="${protoc_generate_grpc_swift}" \
        --proto_path=../../../proto \
        --grpc-swift_opt=Visibility=Public \
        --grpc-swift_out=.

    protoc ../../../proto/landing.proto \
        --plugin=${protoc_gen_swift} \
        --proto_path=../../../proto \
        --swift_opt=Visibility=Public \
        --swift_out=.

    cd ../../..
    echo "Swift gRPC code generation completed"
}

# Function to generate TypeScript gRPC code
generate_ts() {
    echo "Generating TypeScript gRPC code..."
    cd hello-grpc-ts || exit

    npx grpc_tools_node_protoc \
        --grpc_out=grpc_js:common \
        --js_out=import_style=commonjs,binary:common \
        --ts_out=grpc_js:common \
        -I ../proto \
        --plugin=protoc-gen-ts=./node_modules/.bin/protoc-gen-ts \
        ../proto/landing.proto

    cd ..
    echo "TypeScript gRPC code generation completed"
}

# Function to generate Dart gRPC code
generate_dart() {
    echo "Generating Dart gRPC code..."
    cd hello-grpc-flutter || exit

    # Ensure the proto directory exists with symbolic links
    ./proto_link.sh

    # Use protoc with the Dart plugin to generate gRPC code
    # Make sure to have protoc-gen-dart installed via 'dart pub global activate protoc_plugin'
    if ! command -v protoc-gen-dart &>/dev/null; then
        echo "Installing protoc-gen-dart..."
        dart pub global activate protoc_plugin
    fi

    mkdir -p lib/common/grpc

    # Generate the Dart code
    protoc --proto_path=protos \
        --dart_out=grpc:lib/common/grpc \
        protos/landing.proto

    # Update dependencies
    flutter pub get

    cd ..
    echo "Dart gRPC code generation completed"
}

# Function to generate PHP gRPC code
generate_php() {
    echo "Generating PHP gRPC code..."
    cd hello-grpc-php || exit

    # Create common directories if they don't exist
    mkdir -p common/msg
    mkdir -p common/svc

    # Generate PHP code from proto file
    protoc --proto_path="${PROTO_DIR}" \
        --php_out=common/msg \
        "${PROTO_DIR}/landing.proto"

    # Generate PHP gRPC service code
    # The grpc_php_plugin is typically installed with the grpc extension
    if command -v grpc_php_plugin &>/dev/null; then
        GRPC_PHP_PLUGIN=$(which grpc_php_plugin)
    else
        # Try to find it in the default location
        if [ -f "/usr/local/bin/grpc_php_plugin" ]; then
            GRPC_PHP_PLUGIN="/usr/local/bin/grpc_php_plugin"
        else
            echo "ERROR: grpc_php_plugin not found. Please install gRPC PHP extension."
            echo "See: https://github.com/grpc/grpc/tree/master/src/php for installation instructions."
            exit 1
        fi
    fi

    echo "Using gRPC PHP plugin: $GRPC_PHP_PLUGIN"

    protoc --proto_path="${PROTO_DIR}" \
        --grpc_out=common/svc \
        --plugin=protoc-gen-grpc="$GRPC_PHP_PLUGIN" \
        "${PROTO_DIR}/landing.proto"

    # Run composer update to install/update dependencies
    if command -v composer &>/dev/null; then
        echo "Updating composer dependencies..."
        composer update
    else
        echo "WARNING: Composer not found. Please run 'composer update' manually."
    fi

    cd ..
    echo "PHP gRPC code generation completed"
}

# Execute based on the language parameter
case $LANGUAGE in
"go")
    generate_go
    ;;
"js")
    generate_js
    ;;
"php")
    generate_php
    ;;
"py")
    generate_py
    ;;
"swift")
    generate_swift
    ;;
"ts")
    generate_ts
    ;;
"dart")
    generate_dart
    ;;
"all")
    generate_go
    generate_js
    generate_php
    generate_py
    generate_swift
    generate_ts
    generate_dart
    ;;
*)
    echo "Unsupported language: $LANGUAGE"
    echo "Supported languages: go, js, php, py, swift, ts, dart, all"
    exit 1
    ;;
esac

echo "==== gRPC code generation completed for $LANGUAGE ===="
