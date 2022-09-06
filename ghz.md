## [ghz](https://github.com/bojand/ghz)

```bash
brew install ghz
```

https://ghz.sh/docs/examples

### A simple insecure unary call:

```bash
ghz --insecure \
 --proto grpc/proto/landing.proto \
 --call org.feuyeux.grpc.LandingService/Talk \
 -d '{
"data": "0",
"meta": "grpcurl"
}' \
 localhost:9996
```

### Server reflection

```bash
ghz --insecure \
 --call org.feuyeux.grpc.LandingService/Talk \
 -d '{
"data": "0",
"meta": "grpcurl"
}' \
 localhost:9996
```

### Custom parameters

#### Client streaming

```bash
ghz --insecure \
 --call org.feuyeux.grpc.LandingService/TalkMoreAnswerOne \
 -d '[{"data": "0","meta": "grpcurl"},{"data": "1","meta": "grpcurl"},{"data": "2","meta": "grpcurl"}]' \
 localhost:9996
```

#### Custom number of requests/concurrency/connections

```bash
ghz --insecure \
 --call org.feuyeux.grpc.LandingService/Talk \
 -d '{
"data": "0",
"meta": "grpcurl"
}' \
-n 2000 \
-c 20 \
--connections=10 \
localhost:9996
```

#### TLS

```bash
ghz --cname=hello.grpc.io \
--cert="/var/hello_grpc/client_certs/full_chain.pem" \
--key="/var/hello_grpc/client_certs/private.pkcs8.key" \
--cacert="/var/hello_grpc/client_certs/full_chain.pem" \
--call org.feuyeux.grpc.LandingService/Talk \
 -d '{
"data": "0",
"meta": "grpcurl"
}' \
 localhost:9996
```
