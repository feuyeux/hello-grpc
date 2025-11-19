# Build script for TypeScript gRPC project
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

Write-Build "Building TypeScript gRPC project..."

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
    Remove-Item -Path "dist" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "src\proto" -Recurse -Force -ErrorAction SilentlyContinue
}

# Install dependencies
Write-Build "Installing TypeScript dependencies..."
if ($Verbose) {
    npm install
} else {
    npm install --silent
}

# Create proto output directory
$protoDir = "src\proto"
New-Item -ItemType Directory -Force -Path $protoDir | Out-Null

# Generate TypeScript code from proto files
$protoPath = "..\proto\landing.proto"
$pbFile = "$protoDir\landing_pb.d.ts"

$needsProtoGen = $false
if ($Clean -or -not (Test-Path $pbFile)) {
    $needsProtoGen = $true
} elseif ((Get-Item $protoPath).LastWriteTime -gt (Get-Item $pbFile).LastWriteTime) {
    $needsProtoGen = $true
}

if ($needsProtoGen) {
    Write-Build "Generating protobuf code..."
    npx grpc_tools_node_protoc `
        --plugin=protoc-gen-ts=.\node_modules\.bin\protoc-gen-ts.cmd `
        --ts_out=grpc_js:$protoDir `
        --js_out=import_style=commonjs,binary:$protoDir `
        --grpc_out=grpc_js:$protoDir `
        --proto_path=..\proto ..\proto\landing.proto
} else {
    Write-DebugMsg "Protobuf files are up to date, skipping generation"
}

# Compile TypeScript
Write-Build "Compiling TypeScript..."
if ($Verbose) {
    npx tsc
} else {
    npx tsc --pretty
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    npm test
}

Write-Success "Build completed successfully!"
