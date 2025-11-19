# Client start script for Node.js gRPC project
# PowerShell version

param(
    [switch]$Tls,
    [string]$Addr = "",
    [string]$Log = "",
    [int]$Count = 0,
    [switch]$Help
)

# Logging functions
function Write-Info { Write-Host "[CLIENT] $args" -ForegroundColor Cyan }
function Write-ErrorMsg { Write-Host "[ERROR] $args" -ForegroundColor Red }

# Show help
if ($Help) {
    Write-Host "Usage: .\client_start.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Tls              Enable TLS communication"
    Write-Host "  -Addr <address>   Server address to connect to (default: 127.0.0.1:9996)"
    Write-Host "  -Log <level>      Set log level (trace|debug|info|warn|error)"
    Write-Host "  -Count <number>   Number of requests to send"
    Write-Host "  -Help             Show this help message"
    exit 0
}

# Navigate to project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

# Check and install dependencies if needed
Write-Info "Checking and installing dependencies if needed..."
if (-not (Test-Path "node_modules") -or -not (Test-Path "node_modules\@grpc")) {
    Write-Info "Installing required gRPC dependencies..."
    if (-not (Test-Path "package.json")) {
        npm init -y
    }
    npm install @grpc/grpc-js @grpc/proto-loader winston
}

Write-Info "Starting Node.js gRPC client..."

# Build additional arguments
$additionalArgs = @()
if ($Addr) { $additionalArgs += "--addr=$Addr" }
if ($Log) { $additionalArgs += "--log=$Log" }
if ($Count -gt 0) { $additionalArgs += "--count=$Count" }

# Set TLS environment variable if enabled
if ($Tls) {
    $env:GRPC_HELLO_SECURE = "Y"
    Write-Info "TLS enabled"
    
    $env:CERT_BASE_PATH = "d:\garden\var\hello_grpc\client_certs"
    
    if (-not (Test-Path $env:CERT_BASE_PATH) -or -not (Test-Path "$env:CERT_BASE_PATH\myssl_root.cer")) {
        Write-ErrorMsg "Certificate directory does not exist or missing myssl_root.cer: $env:CERT_BASE_PATH"
        exit 1
    }
    
    Write-Info "Using certificates from: $env:CERT_BASE_PATH"
    
    if ($additionalArgs.Count -gt 0) {
        $additionalArgs = @("--tls") + $additionalArgs
    } else {
        $additionalArgs = @("--tls")
    }
}

# Build the command
$cmd = "node proto_client.js"
if ($additionalArgs.Count -gt 0) {
    $cmd += " " + ($additionalArgs -join " ")
}

# Execute the command
Write-Info "Running: $cmd"
Invoke-Expression $cmd
