# grpc java demo

## 1 Generate & Build

```bash
sh build.sh
```

## 2 Run

```bash
mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.server.ProtoServer"
```

```bash
mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.client.ProtoClient"
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