# Start gRPC TLS Client
# This script starts the gRPC client with TLS enabled

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$CERT_PATH = Join-Path $PROJECT_ROOT "docker\tls\client_certs"

Write-Host "Starting gRPC TLS Client..." -ForegroundColor Green
Write-Host "Certificate path: $CERT_PATH" -ForegroundColor Cyan
Write-Host "Server: localhost:50051" -ForegroundColor Cyan
Write-Host ""

# Set environment variables
$env:GRPC_HELLO_SECURE = "Y"
$env:CERT_BASE_PATH = $CERT_PATH
$env:GRPC_SERVER_PORT = "50051"

# Start client
node "$SCRIPT_DIR\proto_client.js"
