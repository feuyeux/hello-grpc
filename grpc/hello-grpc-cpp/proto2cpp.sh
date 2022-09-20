#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

export PATH="$HOME/.local/bin:$PATH"
export PB_PATH=$(pwd)/common
export landing_proto=$(pwd)/protos/landing.proto
export landing_proto_path=$(pwd)/protos

# 与cmake配置文件CMakeLists.txt中的add_custom_command等效
protoc --grpc_out "${PB_PATH}" \
  --cpp_out "${PB_PATH}" \
  -I "${landing_proto_path}" \
  --plugin=protoc-gen-grpc=$HOME/.local/bin/grpc_cpp_plugin \
  "${landing_proto}"
