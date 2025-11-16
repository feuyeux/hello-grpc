@echo off
set GRPC_HELLO_SECURE=Y
set CERT_BASE_PATH=d:\garden\var\hello_grpc\server_certs
go run server/proto_server.go
