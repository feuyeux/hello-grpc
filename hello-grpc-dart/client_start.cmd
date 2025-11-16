@echo off
REM Set environment variables for TLS mode
set GRPC_HELLO_SECURE=Y
set CERT_BASE_PATH=%~dp0..\docker\tls\client_certs
set GRPC_SERVER=127.0.0.1
set GRPC_SERVER_PORT=9996

echo Starting Dart gRPC Client with TLS...
echo GRPC_HELLO_SECURE=%GRPC_HELLO_SECURE%
echo CERT_BASE_PATH=%CERT_BASE_PATH%
echo GRPC_SERVER=%GRPC_SERVER%

dart run client.dart
