# grpc java demo

## 1 Generate & Build

```bash
sh build.sh
```

## 2 Run

```bash
# Server
mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.server.ProtoServer"
# Client
mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.client.ProtoClient"
```

### with etcd

```bash
export GRPC_HELLO_DISCOVERY=etcd
export GRPC_HELLO_DISCOVERY_ENDPOINT=http://127.0.0.1:2379
```

### with nacos

```bash
export GRPC_HELLO_DISCOVERY=nacos
export GRPC_HELLO_DISCOVERY_ENDPOINT=http://127.0.0.1:8848
```

## TLS

```bash
openssl pkcs8 -topk8 -nocrypt -in /var/hello_grpc/server_certs/private.key -out
/var/hello_grpc/server_certs/private.pkcs8.key openssl pkcs8 -topk8 -nocrypt -in
/var/hello_grpc/client_certs/private.key -out /var/hello_grpc/client_certs/private.pkcs8.key
```

## Reference

- [Language Guide (proto3)](https://developers.google.com/protocol-buffers/docs/proto3)
- [gRPC Java Tutorials](https://grpc.io/docs/tutorials/basic/java.html)
- [gRPC-Java - An RPC library and framework](https://github.com/grpc/grpc-java)