## grpc c++ demo

https://grpc.io/docs/languages/cpp/quickstart/

### 1 Setup

[SETUP](SETUP.md)

### 2 Build

#### cmake config

set `$GRPC_INSTALL_PATH` for `CMAKE_PREFIX_PATH`

```cmake
set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} "/Users/han/.local")
```

#### cmake & make

```bash
echo "cmake"
rm -rf build common/*.cc common/*.h
mkdir build
pushd build
cmake ..
echo "make"
make -j8
popd
```

### 3 Run

```bash
./build/proto_server
```

```bash
./build/proto_client
```