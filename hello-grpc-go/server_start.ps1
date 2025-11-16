# PowerShell script to start Go gRPC server
# Usage: .\server_start.ps1 [-tls] [-addr "127.0.0.1:9996"] [-log "info"]

param(
    [switch]$tls,
    [string]$addr = "",
    [string]$log = "",
    [switch]$help
)

# Change to script directory
Set-Location $PSScriptRoot

# Set Go module mode
$env:GO111MODULE = "on"

if ($help) {
    Write-Host "Usage: .\server_start.ps1 [options]"
    Write-Host "Options:"
    Write-Host "  -tls                 Enable TLS communication"
    Write-Host "  -addr HOST:PORT      Specify server address (default: 127.0.0.1:9996)"
    Write-Host "  -log LEVEL           Set log level (trace, debug, info, warn, error)"
    Write-Host "  -help                Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\server_start.ps1                    # Start server without TLS"
    Write-Host "  .\server_start.ps1 -tls               # Start server with TLS"
    Write-Host "  .\server_start.ps1 -tls -log debug    # Start with TLS and debug logging"
    exit 0
}

# Preparation steps
Write-Host "Checking Go gRPC dependencies..." -ForegroundColor Cyan

# Check if go.mod exists
if (-not (Test-Path "go.mod")) {
    Write-Host "Initializing Go module..." -ForegroundColor Yellow
    go mod init github.com/feuyeux/hello-grpc-go
}

# Download dependencies
Write-Host "Downloading Go dependencies..." -ForegroundColor Cyan
go mod tidy

# Build command arguments
$cmdArgs = @("run", "server/proto_server.go")

if ($tls) {
    $cmdArgs += "--tls"
}

if ($addr -ne "") {
    $cmdArgs += "--addr=$addr"
}

if ($log -ne "") {
    $cmdArgs += "--log=$log"
}

# Execute the command
Write-Host "Running: go $($cmdArgs -join ' ')" -ForegroundColor Green
& go $cmdArgs
