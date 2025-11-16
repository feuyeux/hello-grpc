@echo off
REM Set environment variables for TLS mode
set GRPC_HELLO_SECURE=Y
set CERT_BASE_PATH=%~dp0..\docker\tls\server_certs
set GRPC_SERVER_PORT=9996

echo Starting Dart gRPC Server with TLS...
echo GRPC_HELLO_SECURE=%GRPC_HELLO_SECURE%
echo CERT_BASE_PATH=%CERT_BASE_PATH%
echo GRPC_SERVER_PORT=%GRPC_SERVER_PORT%

dart run server.dart
