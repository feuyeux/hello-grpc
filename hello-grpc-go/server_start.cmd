@echo off
REM CMD script to start Go gRPC server
REM Usage: server_start.cmd [--tls] [--addr=HOST:PORT] [--log=LEVEL]

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
    echo Usage: server_start.cmd [options]
    echo Options:
    echo   --tls                 Enable TLS communication
    echo   --addr=HOST:PORT      Specify server address (default: 127.0.0.1:9996^)
    echo   --log=LEVEL           Set log level (trace, debug, info, warn, error^)
    echo   --help                Show this help message
    echo.
    echo Examples:
    echo   server_start.cmd                    # Start server without TLS
    echo   server_start.cmd --tls              # Start server with TLS
    echo   server_start.cmd --tls --log=debug  # Start with TLS and debug logging
    exit /b 0
)
set ADDITIONAL_ARGS=%ADDITIONAL_ARGS% %~1
shift
goto parse_args

:end_parse

REM Preparation steps
echo Checking Go gRPC dependencies...

REM Check if go.mod exists
if not exist "go.mod" (
    echo Initializing Go module...
    go mod init github.com/feuyeux/hello-grpc-go
)

REM Download dependencies
echo Downloading Go dependencies...
go mod tidy

REM Build and execute command
if defined USE_TLS (
    echo Running: go run server/proto_server.go %USE_TLS% %ADDITIONAL_ARGS%
    go run server/proto_server.go %USE_TLS% %ADDITIONAL_ARGS%
) else (
    echo Running: go run server/proto_server.go %ADDITIONAL_ARGS%
    go run server/proto_server.go %ADDITIONAL_ARGS%
)
