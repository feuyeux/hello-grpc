@echo off
cd /d "%~dp0"

echo Checking Rust installation...
where cargo >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Cargo is not installed or not in PATH
    echo Please install Rust from https://rustup.rs/
    pause
    exit /b 1
)

echo Building project...
cargo build --release

echo Starting gRPC client with TLS...
set GRPC_HELLO_SECURE=Y
cargo run --release --bin proto-client

pause
