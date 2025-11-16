@echo off
setlocal

cd /d "%~dp0"
cd HelloServer

echo Cleaning and building C# gRPC Server...
dotnet clean
dotnet build

echo.
echo Starting C# gRPC Server with TLS...
echo.

REM Get the absolute path to server certs
set "CERT_BASE_PATH=%~dp0..\docker\tls\server_certs"

REM Enable TLS
set GRPC_HELLO_SECURE=Y

REM Set server address
set GRPC_SERVER=0.0.0.0
set GRPC_SERVER_PORT=9996

echo Certificate path: %CERT_BASE_PATH%
echo TLS enabled: %GRPC_HELLO_SECURE%
echo Server address: %GRPC_SERVER%:%GRPC_SERVER_PORT%
echo.

dotnet run -- --addr=0.0.0.0:9996

endlocal
