#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

sh build_java.sh
sh build_go.sh
sh build_node.sh
sh build_python.sh
sh build_rust.sh