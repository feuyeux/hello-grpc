#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

rm -rf gen_svc gen_msg
# 1 C++
mkdir -p gen_svc/cpp gen_msg/cpp
export PATH="$HOME/.local/bin:$PATH"
protoc \
  --grpc_out gen_svc/cpp \
  --cpp_out gen_msg/cpp \
  -I protos \
  --plugin=protoc-gen-grpc=$HOME/.local/bin/grpc_cpp_plugin \
  protos/landing.proto

# 2 Rust
echo "../hello-grpc-rust\build.rs"

# 3 Java
echo "../hello-grpc-java\server_pom.xml"

# 4 Go
mkdir -p gen_svc/go gen_msg/go
protoc \
  --go-grpc_out gen_svc/go \
  --go_out gen_msg/go \
  -I protos \
  protos/landing.proto

# 5 C#
echo "../hello-grpc-csharp\Common\Common.csproj"

# 6 Python
export PATH=$PATH:/usr/local/opt/python@3.11/libexec/bin
python -V
pip install protobuf grpcio-tools
mkdir -p gen_svc/py gen_msg/py
python -m grpc.tools.protoc \
  --grpc_python_out gen_svc/py \
  --python_out gen_msg/py \
  -I protos \
  protos/landing.proto

# 7 Node.js
mkdir -p gen_svc/node gen_msg/node
protoc-gen-grpc \
  --grpc_out=grpc_js:gen_svc/node \
  --js_out=import_style=commonjs,binary:gen_msg/node \
  -I protos \
  protos/landing.proto

# 8 TypeScript
# npm config list
# code /Users/han/.npmrc
# npm install typescript -g
# rm -rf node_modules gen_svc/ts gen_msg/ts
# yarn add @grpc/grpc-js google-protobuf 
# yarn add -D grpc-tools grpc_tools_node_protoc_ts typescript
mkdir -p gen_svc/ts gen_msg/ts
grpc_tools_node_protoc \
  --grpc_out=grpc_js:gen_svc/ts \
  --js_out=import_style=commonjs,binary:gen_svc/ts \
  --ts_out=grpc_js:gen_svc/ts \
  -I protos \
  --plugin=protoc-gen-ts=./node_modules/.bin/protoc-gen-ts\
  protos/landing.proto

# 9 Dart
# dart pub global activate protoc_plugin
export PATH="$PATH":"$HOME/.pub-cache/bin"
mkdir -p gen_svc/dart
protoc \
  --dart_out=grpc:gen_svc/dart \
  -I protos \
  protos/landing.proto

# 10 Kotlin
echo "../hello-grpc-kotlin\stub\build.gradle.kts"

# 11 Swift
# brew install swift-protobuf grpc-swift
mkdir -p gen_svc/swift gen_msg/swift
protoc \
  --grpc-swift_opt Visibility=Public \
  --grpc-swift_out gen_svc/swift \
  --swift_opt Visibility=Public \
  --swift_out gen_msg/swift \
  -I protos \
  protos/landing.proto