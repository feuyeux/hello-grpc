#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

# https://gitee.com/feuyeux/grpc/tags
export GRPC_RELEASE_TAG=v1.57.0

# brew install cmake
cmake --version
protoc --version
ld -v

echo " == brew install == "
# brew install autoconf automake libtool pkg-config zlib
# xcode-select --install

echo " == Show me the macos sdk == "
# ls -hlt /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
ls -hlt /Library/Developer/CommandLineTools/SDKs

export GRPC_INSTALL_PATH=$HOME/.local
export BASE_DIR=/Users/han/github
export GRPC_SRC_HOME=$BASE_DIR/grpc
BASE_PATH="$(pwd)"
export BASE_PATH

if [ ! -d "$BASE_DIR" ]; then
  mkdir "$BASE_DIR"
fi

cd "$BASE_DIR"
echo " == clone|checkout grpc sourcecode == "
if [ ! -d "$GRPC_SRC_HOME" ]; then
  export GRPC_REPO=https://gitee.com/feuyeux/grpc.git
  # export GRPC_REPO=https://github.com/grpc/grpc.git
  git clone -b ${GRPC_RELEASE_TAG} ${GRPC_REPO}
  cd "$GRPC_SRC_HOME"
  git submodule update --init --recursive
else
  echo "$GRPC_SRC_HOME dir has benn existed, checkout ${GRPC_RELEASE_TAG}"
  cd "$GRPC_SRC_HOME"
  git checkout ${GRPC_RELEASE_TAG}
  git submodule update --init --recursive
fi

echo " == build and install grpc & protobuf == "
cp "$BASE_PATH"/init_*.sh .
sh init_grpc.sh

echo " == build and install glog == "
cd "$BASE_PATH"
sh init_glog.sh

echo " == build and install catch2 == "
cd "$BASE_PATH"
sh init_catch2.sh

echo " == build and install Abseil == "
cd "$BASE_PATH"
sh init_absl.sh
