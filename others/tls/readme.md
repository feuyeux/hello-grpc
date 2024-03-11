## ALTS authentication
> Application Layer Transport Security (ALTS) 

https://grpc.io/docs/languages/java/alts/

```bash
sh docker/build_go.sh
```

go.tls.server.sh
```bash
docker run --rm --name grpc_server_go -p 9996:9996 \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_server_go:1.0.0
```

go.tls.client.sh
```bash
docker run --rm --name grpc_client_go -e GRPC_SERVER=$(ipconfig getifaddr en0) \
-e GRPC_HELLO_SECURE=Y \
feuyeux/grpc_client_go:1.0.0 ./grpc-client
```