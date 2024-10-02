# grpc c++ demo

## 1 Setup

<https://bazel.build/>
<https://github.com/bazelbuild/bazel/releases>
<https://visualstudio.microsoft.com/downloads/>

### windows

<!-- bazel-7.3.2-windows-x86_64.zip -->

```sh
$ bazel --version
bazel 7.3.2
```

```sh
export BAZEL_VC="C:\Program Files\Microsoft Visual Studio\2022\Community\VC"
```

## 2 Build

<https://github.com/grpc/grpc/blob/master/BUILDING.md#build-from-source>

```sh
export proxy_port=56458
export http_proxy=127.0.0.1:$proxy_port
export https_proxy=127.0.0.1:$proxy_port
```

```sh
echo $https_proxy
```

```sh
$ sh cpu_core_num.sh 
CPU cores=16
```

### 2.1 build hello_cc_grpc

```sh
cd hello-grpc-cpp
bazel clean --expunge 
# hello_cc_grpc -> hello_cc_proto -> hello_proto
bazel build --jobs=32 ///protos:hello_cc_grpc
```

```sh
$ ls bazel-bin/protos/
_objs/             hello_cc_grpc.lib-2.params  landing.grpc.pb.h  landing.pb.h
hello_cc_grpc.lib  landing.grpc.pb.cc          landing.pb.cc
```

#### hello_cc_grpc dependencies

> <https://mermaid.js.org/syntax/flowchart.html>

```mermaid
flowchart LR

subgraph BUILD
    direction TB
    cc_grpc_library --> com_github_grpc_grpc
end

subgraph MODULE
    direction BT
    com_github_grpc_grpc' --> grpc
    grpc --> rules_python
    rules_python --> rules_go
    rules_go --> protobuf
    protobuf --> googleapis
end

BUILD --> MODULE
```

### 2.2 build hello_utils

```sh
bazel build --compiler=$BAZEL_VC --jobs=32 ///common:hello_utils
```

#### hello_utils dependencies

```mermaid
flowchart LR
    subgraph BUILD
        hello_utils --> hello_cc_grpc[[//protos:hello_cc_grpc]]
        hello_utils --> com_github_google_glog
        hello_utils --> com_google_absl
        hello_utils --> com_google_protobuf
    end
    subgraph MODULE
        com_github_google_glog --> glog
        com_google_absl --> abseil-cpp
        com_google_protobuf --> protobuf
    end
```

### 2.3 build hello_conn

```sh
bazel build --compiler=$BAZEL_VC --jobs=32 ///common:hello_conn
```

#### hello_conn dependencies

```mermaid
flowchart LR
    subgraph BUILD
        hello_conn --> hello_utils[[:hello_utils]]
        hello_conn --> hello_cc_grpc[[//protos:hello_cc_grpc]]
        hello_conn --> com_github_google_glog
        hello_conn --> com_google_absl
    end
    subgraph MODULE
        com_github_google_glog --> glog
        com_google_absl --> abseil-cpp
    end
```

### 2.4 build hello_server/client

```sh
export proxy_port=56458
export http_proxy=127.0.0.1:$proxy_port
export https_proxy=127.0.0.1:$proxy_port
```

```sh
bazel build --jobs=32  ///:hello_server ///:hello_client
```

#### hello_server/client dependencies

```mermaid
flowchart LR
    subgraph BUILD
        hello_server --> hello_conn[[//common:hello_conn]]
        hello_server --> hello_utils[[//common:hello_utils]]
        hello_server --> hello_cc_grpc[[//protos:hello_cc_grpc]]
        hello_server --> catch2
        hello_server --> com_github_grpc_grpc
    end
    subgraph MODULE
        catch2 --> catch2'
        com_github_grpc_grpc --> grpc
    end
    subgraph WORKSPACE
        com_github_grpc_grpc --> grpc
    end
```

## 3 Run

```bash
sh server_start.sh
```

```bash
sh client_start.sh
```
