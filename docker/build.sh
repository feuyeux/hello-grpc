#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

# echo " ==== 1 ===="
# sh build_rust.sh
# echo " ==== 2 ===="
# sh build_java.sh
# sh build_transcoder_java.sh
# echo " ==== 3 ===="
# sh build_go.sh
# echo " ==== 4 ===="
# sh build_csharp.sh
# echo " ==== 5 ===="
sh build_node.sh
echo " ==== 6 ===="
sh build_python.sh
echo " ==== 7 ===="
sh build_dart.sh
echo " ==== 8 ===="
sh build_kotlin.sh
echo " ==== 9 ===="
sh build_swift.sh
echo " ==== 10 ===="
sh build_php.sh
echo " ==== 11 ===="
sh build_cpp.sh
