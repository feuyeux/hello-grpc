#!/bin/bash
set -e

export GRPC_INSTALL_PATH=$HOME/.local
export BASE_DIR=/Users/han/github
export GRPC_SRC_HOME=$BASE_DIR/grpc

# rm -rf /usr/local/include/absl
# sed -i "" '20 r CXX_STANDARD_14.txt' "$GRPC_SRC_HOME"/third_party/abseil-cpp/CMakeLists.txt
cd "$GRPC_SRC_HOME"
mkdir -p third_party/abseil-cpp/cmake/build
pushd third_party/abseil-cpp/cmake/build
cmake -DCMAKE_INSTALL_PREFIX="$GRPC_INSTALL_PATH" \
  -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
  ../..
make -j
make install
popd