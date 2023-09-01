#!/bin/bash
set -e

# https://grpc.io/docs/languages/cpp/quickstart/#Build%20The%20Example
echo " == try to build the hello world == "
cd "$GRPC_SRC_HOME/examples/cpp/helloworld"
export MY_INSTALL_DIR=$HOME/.local
mkdir -p $MY_INSTALL_DIR
export PATH="$MY_INSTALL_DIR/bin:$PATH"
mkdir -p cmake/build
pushd cmake/build
cmake -DCMAKE_PREFIX_PATH=$MY_INSTALL_DIR ../..
make -j 4