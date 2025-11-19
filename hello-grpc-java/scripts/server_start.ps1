# Server start script for Java gRPC project
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
    Write-Host "  -Addr <address>   Server address to bind (default: 0.0.0.0:9996)"
    Write-Host "  -Log <level>      Set log level (trace|debug|info|warn|error)"
    Write-Host "  -Help             Show this help message"
    exit 0
}

# Navigate to project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

# Build the project first
Write-Info "Building project..."
& "$ScriptDir\build.ps1"

Write-Info "Starting Java gRPC server..."

# Build additional arguments
$execArgs = @()
if ($Addr) { $execArgs += "--addr=$Addr" }
if ($Log) { $execArgs += "--log=$Log" }

# Set TLS environment variable if enabled
if ($Tls) {
    $env:GRPC_HELLO_SECURE = "Y"
    Write-Info "TLS enabled"
}

# Build the command
$cmd = 'mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.server.ProtoServer"'
if ($execArgs.Count -gt 0) {
    $argsString = $execArgs -join " "
    $cmd += " -Dexec.args=`"$argsString`""
}

# Execute the command
Write-Info "Running: $cmd"
Invoke-Expression $cmd
