#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

cmake --version
protoc --version
ld -v

echo "brew install"
# brew install autoconf automake libtool pkg-config
# xcode-select --install

ls -hlt /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
ls -hlt /Library/Developer/CommandLineTools/SDKs

echo "build and install grpc & protobuf"

if [ ! -d "grpc" ]; then
  # https://gitee.com/feuyeux/grpc/tags
  export GRPC_RELEASE_TAG=v1.53.0
  # export GRPC_REPO=https://gitee.com/feuyeux/grpc.git
  export GRPC_REPO=https://github.com/grpc/grpc.git
  git clone -b ${GRPC_RELEASE_TAG} ${GRPC_REPO}
else
  echo "grpc dir has benn existed"
fi

cd grpc
git submodule update --init --recursive

sh init_grpc.sh

echo "build and install glog"

sh init_glog.sh

echo "build and install Abseil"

# edit third_party/abseil-cpp/CMakeLists.txt

# # Add c++11 flags
# if (NOT DEFINED CMAKE_CXX_STANDARD)
#   set(CMAKE_CXX_STANDARD 11)
# else()
#   if (CMAKE_CXX_STANDARD LESS 11)
#     message(FATAL_ERROR "CMAKE_CXX_STANDARD is less than 11, please specify at least SET(CMAKE_CXX_STANDARD 11)")
#   endif()
# endif()
# if (NOT DEFINED CMAKE_CXX_STANDARD_REQUIRED)
#   set(CMAKE_CXX_STANDARD_REQUIRED ON)
# endif()
# if (NOT DEFINED CMAKE_CXX_EXTENSIONS)
#   set(CMAKE_CXX_EXTENSIONS OFF)
# endif()

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
