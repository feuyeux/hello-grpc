```bash
cmake --version
brew install autoconf automake libtool pkg-config

cd /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
sudo ln -s MacOSX.sdk MacOSX11.1.sdk
```

#### Build and install gRPC, Protocol Buffers, and Abseil

```bash
export GRPC_INSTALL_PATH=$HOME/.local
mkdir -p $GRPC_INSTALL_PATH
export PATH="$GRPC_INSTALL_PATH/bin:$PATH"
```

```bash
export GRPC_RELEASE_TAG=v1.40.0
git clone -b ${GRPC_RELEASE_TAG} https://gitee.com/feuyeux/grpc
cd grpc
git submodule update --init --recursive
mkdir -p cmake/build
pushd cmake/build
cmake -DgRPC_INSTALL=ON \
      -DgRPC_BUILD_TESTS=OFF \
      -DCMAKE_INSTALL_PREFIX=$GRPC_INSTALL_PATH \
      ../..
make -j$(nproc)
make install
popd
```

edit third_party/abseil-cpp/CMakeLists.txt

```bash
# Add c++11 flags
if (NOT DEFINED CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 11)
else()
  if (CMAKE_CXX_STANDARD LESS 11)
    message(FATAL_ERROR "CMAKE_CXX_STANDARD is less than 11, please specify at least SET(CMAKE_CXX_STANDARD 11)")
  endif()
endif()
if (NOT DEFINED CMAKE_CXX_STANDARD_REQUIRED)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if (NOT DEFINED CMAKE_CXX_EXTENSIONS)
  set(CMAKE_CXX_EXTENSIONS OFF)
endif()
```

```bash
mkdir -p third_party/abseil-cpp/cmake/build
pushd third_party/abseil-cpp/cmake/build
cmake -DCMAKE_INSTALL_PREFIX=$GRPC_INSTALL_PATH \
      -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
      ../..
make -j
make install
popd
```
