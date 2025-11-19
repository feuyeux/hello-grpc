# Build script for Node.js gRPC project
# PowerShell version

param(
    [switch]$Clean,
    [switch]$Test,
    [switch]$Verbose,
    [switch]$Help
)

# Logging functions
function Write-Build { Write-Host "[BUILD] $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "[SUCCESS] $args" -ForegroundColor Green }
function Write-ErrorMsg { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-DebugMsg { if ($Verbose) { Write-Host "[DEBUG] $args" -ForegroundColor Gray } }

# Show help
if ($Help) {
    Write-Host "Usage: .\build.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Clean       Clean build artifacts before building"
    Write-Host "  -Test        Run tests after building"
    Write-Host "  -Verbose     Enable verbose output"
    Write-Host "  -Help        Show this help message"
    exit 0
}

# Navigate to project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

Write-Build "Building Node.js gRPC project..."

# Check for Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Node.js is not installed or not in PATH"
    Write-ErrorMsg "Please install Node.js from: https://nodejs.org/"
    exit 1
}

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    Remove-Item -Path "node_modules" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "src\proto" -Recurse -Force -ErrorAction SilentlyContinue
}

# Check for node_modules
$needsInstall = $false
if (-not (Test-Path "node_modules") -or -not (Test-Path "node_modules\.package-lock.json")) {
    $needsInstall = $true
} elseif ((Get-Item "package.json").LastWriteTime -gt (Get-Item "node_modules\.package-lock.json").LastWriteTime) {
    $needsInstall = $true
}

if ($needsInstall) {
    Write-Build "Installing Node.js dependencies..."
    if ($Verbose) {
        npm install
    } else {
        npm install --silent
    }
} else {
    Write-DebugMsg "Dependencies are up to date, skipping installation"
}

# Create proto output directory
$protoDir = "src\proto"
New-Item -ItemType Directory -Force -Path $protoDir | Out-Null

# Generate JavaScript code from proto files
$protoPath = "..\proto\landing.proto"
$pbFile = "$protoDir\landing_pb.js"
$grpcFile = "$protoDir\landing_grpc_pb.js"

$needsProtoGen = $false
if ($Clean -or -not (Test-Path $pbFile) -or -not (Test-Path $grpcFile)) {
    $needsProtoGen = $true
} elseif ((Get-Item $protoPath).LastWriteTime -gt (Get-Item $pbFile).LastWriteTime) {
    $needsProtoGen = $true
}

if ($needsProtoGen) {
    Write-Build "Generating protobuf code..."
    npx grpc_tools_node_protoc `
        --js_out=import_style=commonjs,binary:$protoDir `
        --grpc_out=grpc_js:$protoDir `
        --proto_path=..\proto ..\proto\landing.proto
} else {
    Write-DebugMsg "Protobuf files are up to date, skipping generation"
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    npm test
}

Write-Success "Build completed successfully!"
