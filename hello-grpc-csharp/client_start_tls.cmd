@echo off
setlocal

cd /d "%~dp0"
cd HelloClient

echo Cleaning C# gRPC Client...
dotnet clean

echo.
echo Starting C# gRPC Client with TLS...
echo.

REM Get the absolute path to client certs
set "CERT_BASE_PATH=%~dp0..\docker\tls\client_certs"

REM Enable TLS
set GRPC_HELLO_SECURE=Y

REM Set server address to connect to
set GRPC_SERVER=localhost
set GRPC_SERVER_PORT=9996

echo Certificate path: %CERT_BASE_PATH%
echo TLS enabled: %GRPC_HELLO_SECURE%
echo Connecting to: %GRPC_SERVER%:%GRPC_SERVER_PORT%
echo.

dotnet run -- --addr=localhost:9996

endlocal
