#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e
export GRPC_INSTALL_PATH=$HOME/.local
mkdir -p "$GRPC_INSTALL_PATH"
export PATH="$GRPC_INSTALL_PATH/bin:$PATH"

if [ ! -d "cmake/build" ]; then
    echo "mkdir cmake/build"
    mkdir -p cmake/build
else
    echo "clean cmake/build"
    rm -rf cmake/build
    mkdir -p cmake/build
fi


pushd cmake/build
cmake -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX="$GRPC_INSTALL_PATH" \
    ../..
# brew install coreutils
# nproc --version
# alias nproc="sysctl -n hw.logicalcpu"
# make -j$(nproc)
make -j 4
make install
popd
echo "done"
