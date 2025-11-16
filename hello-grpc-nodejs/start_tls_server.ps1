# Start gRPC TLS Server
# This script starts the gRPC server with TLS enabled

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$CERT_PATH = Join-Path $PROJECT_ROOT "docker\tls\server_certs"

Write-Host "Starting gRPC TLS Server..." -ForegroundColor Green
Write-Host "Certificate path: $CERT_PATH" -ForegroundColor Cyan
Write-Host "Server port: 50051" -ForegroundColor Cyan
Write-Host ""

# Set environment variables
$env:GRPC_HELLO_SECURE = "Y"
$env:CERT_BASE_PATH = $CERT_PATH
$env:GRPC_SERVER_PORT = "50051"

# Start server
node "$SCRIPT_DIR\proto_server.js"
