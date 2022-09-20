#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e
export GRPC_INSTALL_PATH=$HOME/.local
mkdir -p $GRPC_INSTALL_PATH
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
    -DCMAKE_INSTALL_PREFIX=$GRPC_INSTALL_PATH \
    ../..
make -j$(nproc)
make install
popd
echo "done"

ls -hlt $GRPC_INSTALL_PATH

# drwxr-xr-x  89 han  staff   2.8K  9 14 17:08 lib
# drwxr-xr-x  13 han  staff   416B  9 14 17:08 include
# drwxr-xr-x  14 han  staff   448B  9 14 17:08 bin
# drwxr-xr-x   7 han  staff   224B  9 14 17:08 share

protoc --version
#libprotoc 3.19.4

which protoc
#/Users/han/.local/bin/protoc
