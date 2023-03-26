#!/bin/bash
set -e
export GRPC_INSTALL_PATH=$HOME/.local
#
if [ ! -d "$HOME/github/gflags" ]; then
    cd "$HOME"/github
    git clone https://gitee.com/feuyeux/gflags
fi
cd $HOME/github/gflags
rm -rf build
cmake -S . -B build -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$GRPC_INSTALL_PATH"
cmake --build build --target install
#
if [ ! -d "$HOME/github/glog" ]; then
    cd "$HOME"/github
    git clone https://gitee.com/feuyeux/glog
fi
cd "$HOME"/github/glog
rm -rf build
cmake -S . -B build -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$GRPC_INSTALL_PATH"
cmake --build build --target install
