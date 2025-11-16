# Start gRPC TLS Client (TypeScript)
# This script starts the TypeScript gRPC client with TLS enabled

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$CERT_PATH = Join-Path $PROJECT_ROOT "docker\tls\client_certs"

Write-Host "Starting gRPC TLS Client (TypeScript)..." -ForegroundColor Green
Write-Host "Certificate path: $CERT_PATH" -ForegroundColor Cyan
Write-Host "Server: localhost:50052" -ForegroundColor Cyan
Write-Host ""

# Build TypeScript if needed
if (-not (Test-Path "$SCRIPT_DIR\dist\hello_client.js")) {
    Write-Host "Building TypeScript project..." -ForegroundColor Yellow
    npm run build
    Copy-Item "$SCRIPT_DIR\common\*.js" "$SCRIPT_DIR\dist\common\" -Force
    Copy-Item "$SCRIPT_DIR\common\*.d.ts" "$SCRIPT_DIR\dist\common\" -Force
}

# Set environment variables
$env:GRPC_HELLO_SECURE = "Y"
$env:CERT_BASE_PATH = $CERT_PATH
$env:GRPC_SERVER_PORT = "50052"

# Start client
node "$SCRIPT_DIR\dist\hello_client.js"
