# grpc golang demo

## 1 Setup

```bash
sh init.sh
```

## 2 Generate

```bash
sh proto2go.sh
```

## 3 Build

```bash
go mod tidy
go fmt hello-grpc/...
go fmt server/proto_server.go
go fmt client/proto_client.go
go install server/proto_server.go
go install client/proto_client.go
```

## 4 Run

```bash
sh server_start.sh
```

```bash
sh client_start.sh
```
