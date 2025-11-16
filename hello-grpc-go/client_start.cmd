@echo off
REM CMD script to start Go gRPC client
REM Usage: client_start.cmd [--tls] [--addr=HOST:PORT] [--log=LEVEL] [--count=NUMBER]

cd /d "%~dp0"
set GO111MODULE=on

REM Parse arguments
set USE_TLS=
set ADDITIONAL_ARGS=

:parse_args
if "%~1"=="" goto end_parse
if /i "%~1"=="--tls" (
    set USE_TLS=--tls
    shift
    goto parse_args
)
if /i "%~1"=="--help" (
    echo Usage: client_start.cmd [options]
    echo Options:
    echo   --tls                 Enable TLS communication
    echo   --addr=HOST:PORT      Specify server address to connect to (default: 127.0.0.1:9996^)
    echo   --log=LEVEL           Set log level (trace, debug, info, warn, error^)
    echo   --count=NUMBER        Number of requests to send
    echo   --help                Show this help message
    echo.
    echo Examples:
    echo   client_start.cmd                    # Connect without TLS
    echo   client_start.cmd --tls              # Connect with TLS
    echo   client_start.cmd --tls --log=debug  # Connect with TLS and debug logging
    exit /b 0
)
set ADDITIONAL_ARGS=%ADDITIONAL_ARGS% %~1
shift
goto parse_args

:end_parse

REM Build and execute command
if defined USE_TLS (
    echo Running: go run client/proto_client.go %USE_TLS% %ADDITIONAL_ARGS%
    go run client/proto_client.go %USE_TLS% %ADDITIONAL_ARGS%
) else (
    echo Running: go run client/proto_client.go %ADDITIONAL_ARGS%
    go run client/proto_client.go %ADDITIONAL_ARGS%
)
