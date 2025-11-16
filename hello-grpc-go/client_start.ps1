# PowerShell script to start Go gRPC client
# Usage: .\client_start.ps1 [-tls] [-addr "127.0.0.1:9996"] [-log "info"] [-count 1]

param(
    [switch]$tls,
    [string]$addr = "",
    [string]$log = "",
    [string]$count = "",
    [switch]$help
)

# Change to script directory
Set-Location $PSScriptRoot

# Set Go module mode
$env:GO111MODULE = "on"

if ($help) {
    Write-Host "Usage: .\client_start.ps1 [options]"
    Write-Host "Options:"
    Write-Host "  -tls                 Enable TLS communication"
    Write-Host "  -addr HOST:PORT      Specify server address to connect to (default: 127.0.0.1:9996)"
    Write-Host "  -log LEVEL           Set log level (trace, debug, info, warn, error)"
    Write-Host "  -count NUMBER        Number of requests to send"
    Write-Host "  -help                Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\client_start.ps1                    # Connect without TLS"
    Write-Host "  .\client_start.ps1 -tls               # Connect with TLS"
    Write-Host "  .\client_start.ps1 -tls -log debug    # Connect with TLS and debug logging"
    exit 0
}

# Build command arguments
$cmdArgs = @("run", "client/proto_client.go")

if ($tls) {
    $cmdArgs += "--tls"
}

if ($addr -ne "") {
    $cmdArgs += "--addr=$addr"
}

if ($log -ne "") {
    $cmdArgs += "--log=$log"
}

if ($count -ne "") {
    $cmdArgs += "--count=$count"
}

# Execute the command
Write-Host "Running: go $($cmdArgs -join ' ')" -ForegroundColor Green
& go $cmdArgs
