# Server start script for Python gRPC project
# PowerShell version

param(
    [switch]$Tls,
    [string]$Addr = "",
    [string]$Log = "",
    [switch]$Help
)

# Logging functions
function Write-Info { Write-Host "[SERVER] $args" -ForegroundColor Cyan }
function Write-ErrorMsg { Write-Host "[ERROR] $args" -ForegroundColor Red }

# Show help
if ($Help) {
    Write-Host "Usage: .\server_start.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Tls              Enable TLS communication"
    Write-Host "  -Addr <address>   Server address to bind (default: 127.0.0.1:9996)"
    Write-Host "  -Log <level>      Set log level (trace|debug|info|warn|error)"
    Write-Host "  -Help             Show this help message"
    exit 0
}

# Navigate to project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

# Check and activate virtual environment
if (Test-Path "venv") {
    Write-Info "Activating virtual environment..."
    & "venv\Scripts\Activate.ps1"
}

# Check Python gRPC dependencies
Write-Info "Checking Python gRPC dependencies..."
$checkResult = python -c "import grpc, google.protobuf" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Info "Installing required Python gRPC dependencies..."
    pip install grpcio grpcio-tools protobuf --upgrade
}

Write-Info "Starting Python gRPC server..."

# Build additional arguments
$additionalArgs = @()
if ($Addr) { $additionalArgs += "--addr=$Addr" }
if ($Log) { $additionalArgs += "--log=$Log" }

# Set TLS environment variable if enabled
if ($Tls) {
    $env:GRPC_HELLO_SECURE = "Y"
    Write-Info "TLS enabled"
    
    $env:CERT_BASE_PATH = "d:\garden\var\hello_grpc\server_certs"
    
    if (-not (Test-Path $env:CERT_BASE_PATH)) {
        Write-ErrorMsg "Certificate directory does not exist: $env:CERT_BASE_PATH"
        exit 1
    }
    
    $requiredFiles = @("cert.pem", "private.key", "full_chain.pem", "myssl_root.cer")
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path "$env:CERT_BASE_PATH\$file")) {
            Write-ErrorMsg "Required certificate file missing: $file"
            exit 1
        }
    }
    
    Write-Info "Using certificates from: $env:CERT_BASE_PATH"
}

# Build the command
$cmd = "python server\protoServer.py"
if ($additionalArgs.Count -gt 0) {
    $cmd += " " + ($additionalArgs -join " ")
}

# Execute the command
Write-Info "Running: $cmd"
Invoke-Expression $cmd
