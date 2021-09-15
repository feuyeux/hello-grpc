## grpc c++ demo

https://grpc.io/docs/languages/cpp/quickstart/

### 1 Setup
[SETUP](SETUP.md)

### 2 Build

#### cmake config

set `$MY_INSTALL_DIR` for `CMAKE_PREFIX_PATH`

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
make -j
popd
```

### 3 Run
```bash
./build/proto_server
```

```bash
./build/proto_client
```


```bash
./greeter_async_server
```

```bash
./greeter_async_client
```

```bash
./greeter_async_client2
```