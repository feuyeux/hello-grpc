# build docker images

## build all images

```sh
sh build.sh
```

## push all images

```sh
sh push.sh
```

## verify

### clean all containers

```sh
sh tools/clean_world.sh
```

### 1 java

#### INSECURE

```sh
docker run --rm --name grpc_server_java -p 9996:9996 feuyeux/grpc_server_java:1.0.0
```

```sh
docker run --rm --name grpc_client_java -e GRPC_SERVER=$(ipconfig getifaddr en0) feuyeux/grpc_client_java:1.0.0

docker run --rm --name grpc_client_java -e GRPC_SERVER=host.docker.internal feuyeux/grpc_client_java:1.0.0
```

#### TLS

```sh
docker run --rm --name grpc_server_java -p 9996:9996 \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_server_java:1.0.0
```

```sh
docker run --rm --name grpc_client_java \
-e GRPC_SERVER=$(ipconfig getifaddr en0) \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_client_java:1.0.0

docker run --rm --name grpc_client_java \
-e GRPC_SERVER=host.docker.internal \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_client_java:1.0.0
```

### 2 go

```sh
docker run --rm --name grpc_server_go -p 9996:9996 feuyeux/grpc_server_go:1.0.0
```

```sh
docker run --rm --name grpc_client_go -e GRPC_SERVER=$(ipconfig getifaddr en0) feuyeux/grpc_client_go:1.0.0

docker run --rm --name grpc_client_go -e GRPC_SERVER=host.docker.internal feuyeux/grpc_client_go:1.0.0
```

### 3 node

```sh
docker run --rm --name grpc_server_node -p 9996:9996 \
feuyeux/grpc_server_node:1.0.0
```

```sh
docker run --rm --name grpc_client_node -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_node:1.0.0
```

### 4 python

```sh
docker run --rm --name grpc_server_python -p 9996:9996 \
feuyeux/grpc_server_python:1.0.0
```

```sh
docker run --rm --name grpc_client_python -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_python:1.0.0
```

### 5 rust

```sh
docker run --rm --name grpc_server_rust -p 9996:9996 \
feuyeux/grpc_server_rust:1.0.0
```

```sh
docker run --rm --name grpc_client_rust -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_rust:1.0.0
```

### 6 kotlin

```sh
docker run --rm --name grpc_server_kotlin -p 9996:9996 \
feuyeux/grpc_server_kotlin:1.0.0
```

```sh
docker run --rm --name grpc_client_kotlin -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_kotlin:1.0.0
```

### 7 csharp

```sh
docker run --rm --name grpc_server_csharp -p 9996:9996 \
feuyeux/grpc_server_csharp:1.0.0

docker run --rm --name grpc_server_csharp -p 9996:9996 \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_server_csharp:1.0.0
```

```sh
docker run --rm --name grpc_client_csharp -e GRPC_SERVER=host.docker.internal \
feuyeux/grpc_client_csharp:1.0.0

docker run --rm --name grpc_client_csharp -e GRPC_SERVER=$(ipconfig getifaddr en0) \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_client_csharp:1.0.0
```

### 8 cpp

```sh
docker run --rm --name grpc_server_cpp -p 9996:9996 feuyeux/grpc_server_cpp:1.0.0
```

```sh
docker run --rm --name grpc_client_cpp -e GRPC_SERVER=$(ipconfig getifaddr en0) feuyeux/grpc_client_cpp:1.0.0

docker run --rm --name grpc_client_cpp -e GRPC_SERVER=host.docker.internal feuyeux/grpc_client_cpp:1.0.0
```

### 9 php


```sh
docker run --rm --name grpc_server_php -p 9996:9996 feuyeux/grpc_server_php:1.0.0
```

```sh
docker run --rm --name grpc_client_php -e GRPC_SERVER=$(ipconfig getifaddr en0) feuyeux/grpc_client_php:1.0.0

docker run --rm --name grpc_client_php -e GRPC_SERVER=host.docker.internal feuyeux/grpc_client_php:1.0.0
```

### 10 typescript

```sh
docker run --rm --name grpc_server_ts -p 9996:9996 feuyeux/grpc_server_ts:1.0.0
```

```sh
docker run --rm --name grpc_client_ts -e GRPC_SERVER=$(ipconfig getifaddr en0) feuyeux/grpc_client_ts:1.0.0
```


### 11 dart

```sh
docker run --rm --name grpc_server_dart -p 9996:9996 feuyeux/grpc_server_dart:1.0.0
```

```sh
docker run --rm --name grpc_client_dart -e GRPC_SERVER=$(ipconfig getifaddr en0) feuyeux/grpc_client_dart:1.0.0
```

### 12 swift

```sh
docker run --rm --name grpc_server_swift -p 9996:9996 feuyeux/grpc_server_swift:1.0.0
```

```sh
docker run --rm --name grpc_client_swift -e GRPC_SERVER=$(ipconfig getifaddr en0) feuyeux/grpc_client_swift:1.0.0
```