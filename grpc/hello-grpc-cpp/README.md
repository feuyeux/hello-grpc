# grpc c++ demo

<https://grpc.io/docs/languages/cpp/quickstart/>

## 1 Setup

```bash
sh init.sh
```

## 2 Build

### cmake config

`CMakeLists.txt`

> set `$GRPC_INSTALL_PATH` for `CMAKE_PREFIX_PATH`

```cmake
set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} "/Users/han/.local")
```

### cmake & make

```bash
sh build.sh
```

## 3 Run

```bash
./build/proto_server
```

```bash
./build/proto_client
```
