# build docker images

## build all images

```bash
sh build.sh
```

## push all images

```bash
sh push.sh
```

## verify

### clean all containers

```bash
sh clean_world.sh
```

### 1 java

#### INSECURE

```bash
docker run --rm --name grpc_server_java -p 9996:9996 feuyeux/grpc_server_java:1.0.0
```

```bash
docker run --rm --name grpc_client_java -e GRPC_SERVER=$(ipconfig getifaddr en0) feuyeux/grpc_client_java:1.0.0

docker run --rm --name grpc_client_java -e GRPC_SERVER=host.docker.internal feuyeux/grpc_client_java:1.0.0
```

#### TLS

```bash
docker run --rm --name grpc_server_java -p 9996:9996 \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_server_java:1.0.0
```

```bash
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

```bash
docker run --rm --name grpc_server_go -p 9996:9996 \
feuyeux/grpc_server_go:1.0.0
```

```bash
docker run --rm --name grpc_client_go -e GRPC_SERVER=$(ipconfig getifaddr en0) feuyeux/grpc_client_go:1.0.0

docker run --rm --name grpc_client_go -e GRPC_SERVER=host.docker.internal feuyeux/grpc_client_go:1.0.0
```

### 3 node

```bash
docker run --rm --name grpc_server_node -p 9996:9996 \
feuyeux/grpc_server_node:1.0.0
```

```bash
docker run --rm --name grpc_client_node -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_node:1.0.0
```

### 4 python

```bash
docker run --rm --name grpc_server_python -p 9996:9996 \
feuyeux/grpc_server_python:1.0.0
```

```bash
docker run --rm --name grpc_client_python -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_python:1.0.0
```

### 5 rust

```bash
docker run --rm --name grpc_server_rust -p 9996:9996 \
feuyeux/grpc_server_rust:1.0.0
```

```bash
docker run --rm --name grpc_client_rust -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_rust:1.0.0
```

### 6 kotlin

```bash
docker run --rm --name grpc_server_kotlin -p 9996:9996 \
feuyeux/grpc_server_kotlin:1.0.0
```

```bash
docker run --rm --name grpc_client_kotlin -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_kotlin:1.0.0
```

### 7 csharp

```bash
docker run --rm --name grpc_server_csharp -p 9996:9996 \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_server_csharp:1.0.0
```

```bash
docker run --rm --name grpc_client_csharp -e GRPC_SERVER=$(ipconfig getifaddr en0) \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_client_csharp:1.0.0
```

### 8 cpp

```bash
docker run --rm --name grpc_server_cpp -p 9996:9996 \
feuyeux/grpc_server_cpp:1.0.0
```

```bash
docker run --rm --name grpc_client_cpp -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_cpp:1.0.0
```
