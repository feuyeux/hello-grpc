
### build all images
```bash
sh build.sh
```

### push all images
```bash
sh push.sh
```

### verify

#### clean all containers
```bash
sh clean_world.sh
```

#### java
```bash
docker run --rm --name grpc_server_java -p 9996:9996 \
feuyeux/grpc_server_java:1.0.0
```

```bash
docker run --rm --name grpc_client_java -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_java:1.0.0 java -jar /grpc-client.jar
```

#### go
```bash
docker run --rm --name grpc_server_go -p 9996:9996 \
feuyeux/grpc_server_go:1.0.0
```

```bash
docker run --rm --name grpc_client_go -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_go:1.0.0 ./grpc-client
```

#### node
```bash
docker run --rm --name grpc_server_node -p 9996:9996 \
feuyeux/grpc_server_node:1.0.0
```

```bash
docker run --rm --name grpc_client_node -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_node:1.0.0 node proto_client.js
```

#### python
```bash
docker run --rm --name grpc_server_python -p 9996:9996 \
feuyeux/grpc_server_python:1.0.0
```

```bash
docker run --rm --name grpc_client_python -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_python:1.0.0 sh /grpc-client/start_client.sh
```

#### rust
```bash
docker run --rm --name grpc_server_rust -p 9996:9996 \
feuyeux/grpc_server_rust:1.0.0
```

```bash
docker run --rm --name grpc_client_rust -e GRPC_SERVER=$(ipconfig getifaddr en0) \
feuyeux/grpc_client_rust:1.0.0 ./grpc-client
```