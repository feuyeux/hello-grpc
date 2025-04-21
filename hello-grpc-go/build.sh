#!/bin/bash
export GOPROXY=https://mirrors.aliyun.com/goproxy/
go mod tidy
go fmt hello-grpc/...
go fmt server/proto_server.go
go fmt client/proto_client.go
go install server/proto_server.go
go install client/proto_client.go
