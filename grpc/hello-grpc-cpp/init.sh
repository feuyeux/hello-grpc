#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e
cmake --version
protoc --version
ld -v

echo " == brew install == "
# brew install autoconf automake libtool pkg-config
# xcode-select --install

ls -hlt /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
ls -hlt /Library/Developer/CommandLineTools/SDKs

export GRPC_INSTALL_PATH=$HOME/.local
export GRPC_SRC_HOME=$HOME/github/grpc
BASE_PATH="$(pwd)"
export BASE_PATH

if [ ! -d "$HOME/github" ]; then
  mkdir "$HOME"/github
fi

cd "$HOME"/github
echo " == build and install grpc & protobuf == "
if [ ! -d "$GRPC_SRC_HOME" ]; then
  # https://gitee.com/feuyeux/grpc/tags
  export GRPC_RELEASE_TAG=v1.53.0
  export GRPC_REPO=https://gitee.com/feuyeux/grpc.git
  # export GRPC_REPO=https://github.com/grpc/grpc.git
  git clone -b ${GRPC_RELEASE_TAG} ${GRPC_REPO}
else
  echo "$GRPC_SRC_HOME dir has benn existed"
fi
cd "$GRPC_SRC_HOME"
git submodule update --init --recursive

cp "$BASE_PATH"/init_*.sh .
sh init_grpc.sh

echo " == build and install glog == "
cd "$BASE_PATH"
sh init_glog.sh

echo " == build and install Abseil == "
sed -i "" '20 r CXX_STANDARD_14.txt' "$GRPC_SRC_HOME"/third_party/abseil-cpp/CMakeLists.txt

cd "$GRPC_SRC_HOME"
mkdir -p third_party/abseil-cpp/cmake/build
pushd third_party/abseil-cpp/cmake/build
cmake -DCMAKE_INSTALL_PREFIX="$GRPC_INSTALL_PATH" \
  -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
  ../..
make -j
make install
popd

ls -lht "$GRPC_INSTALL_PATH"

brew install coreutils
nproc --version
