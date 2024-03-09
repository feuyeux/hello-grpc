# grpc c++ demo

<https://grpc.io/docs/languages/cpp/quickstart/>

## 1 Setup

```bash
sh init.sh
```

windows

<https://visualstudio.microsoft.com/downloads/>

BAZEL_VC
C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC

```powershell
cd c:\cooding\grpc
bazel build :all
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

## 4 Test

```bash
./build/tests
```
