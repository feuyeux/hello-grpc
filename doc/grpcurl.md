## [gRPCurl](https://github.com/fullstorydev/grpcurl)

### Install

```bash
brew install grpcurl
```

### Query API

```bash
grpcurl -plaintext localhost:9996 list
grpcurl -plaintext localhost:9996 list org.feuyeux.grpc.LandingService
grpcurl -plaintext localhost:9996 describe org.feuyeux.grpc.LandingService.TalkMoreAnswerOne
```

### Insecure requests

#### 1 Unary RPC"

```bash
echo "Unary RPC with reflection"
grpcurl -plaintext -d @ localhost:9996 org.feuyeux.grpc.LandingService/Talk <<EOM
{
"data": "0",
"meta": "grpcurl"
}
EOM

echo "Unary RPC with proto"
grpcurl -proto grpc/proto/landing.proto -plaintext -d @ localhost:9996 org.feuyeux.grpc.LandingService/Talk <<EOM
{
"data": "0",
"meta": "grpcurl"
}
EOM
```

#### 2 Server streaming RPC

```bash
echo "Server streaming RPC"
grpcurl -plaintext -d @ localhost:9996 org.feuyeux.grpc.LandingService/TalkOneAnswerMore <<EOM
{
"data": "0,1,2",
"meta": "grpcurl"
}
EOM
```

#### 3 Client streaming RPC

```bash
echo "Client streaming RPC"
grpcurl -plaintext -d @ localhost:9996 org.feuyeux.grpc.LandingService/TalkMoreAnswerOne <<EOM
{
"data": "0",
"meta": "grpcurl"
}
{
"data": "1",
"meta": "grpcurl"
}
{
"data": "2",
"meta": "grpcurl"
}
EOM
```

#### 4 Bidirectional streaming RPC

```bash
grpcurl -plaintext -d @ localhost:9996 org.feuyeux.grpc.LandingService/TalkBidirectional <<EOM
{
"data": "0",
"meta": "grpcurl"
}
{
"data": "1",
"meta": "grpcurl"
}
{
"data": "2",
"meta": "grpcurl"
}
EOM
```

### TLS requests

```bash
grpcurl -servername hello.grpc.io \
-cert "/var/hello_grpc/client_certs/full_chain.pem" \
-key "/var/hello_grpc/client_certs/private.key" \
-cacert "/var/hello_grpc/client_certs/full_chain.pem" \
-d @ localhost:9996 org.feuyeux.grpc.LandingService/Talk <<EOM
{
"data": "0",
"meta": "grpcurl"
}
EOM
```
