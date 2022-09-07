#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

sh build_java.sh
sh build_transcoder_java.sh
sh build_go.sh
sh build_node.sh
sh build_python.sh
sh build_rust.sh
sh build_kotlin.sh
sh build_csharp.sh
sh build_cpp.sh
