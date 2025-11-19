# Build script for Go gRPC project
# PowerShell version

param(
    [switch]$Clean,
    [switch]$Test,
    [switch]$Release,
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
    Write-Host "  -Release     Build in release mode (optimized)"
    Write-Host "  -Verbose     Enable verbose output"
    Write-Host "  -Help        Show this help message"
    exit 0
}

# Navigate to project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

Write-Build "Building Go gRPC project..."

# Display Go version
if ($Verbose) {
    $goVersion = go version
    Write-Build "Go version: $goVersion"
}

# Check if Go is installed
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Go is not installed"
    Write-ErrorMsg "Install from: https://golang.org/dl/"
    exit 1
}

# Check if protoc is installed
if (-not (Get-Command protoc -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "protoc is not installed"
    Write-ErrorMsg "Install from: https://github.com/protocolbuffers/protobuf/releases"
    exit 1
}

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    Remove-Item -Path "bin" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "common\pb" -Recurse -Force -ErrorAction SilentlyContinue
}

# Configure GOPROXY for faster downloads
$env:GOPROXY = "https://proxy.golang.org,direct"

# Update Go modules
Write-Build "Updating Go modules..."
go mod tidy

# Create pb directory for generated code
New-Item -ItemType Directory -Force -Path "common\pb" | Out-Null

# Generate Go code from proto files
$pbFile = "common\pb\landing.pb.go"
$grpcFile = "common\pb\landing_grpc.pb.go"
$protoFile = "..\proto\landing.proto"

$needsProtoGen = $false
if ($Clean -or -not (Test-Path $pbFile) -or -not (Test-Path $grpcFile)) {
    $needsProtoGen = $true
} elseif ((Get-Item $protoFile).LastWriteTime -gt (Get-Item $pbFile).LastWriteTime) {
    $needsProtoGen = $true
}

if ($needsProtoGen) {
    Write-Build "Generating protobuf code..."
    protoc -I ..\proto `
        --go_out=.\common\pb --go_opt=paths=source_relative `
        --go-grpc_out=.\common\pb --go-grpc_opt=paths=source_relative `
        ..\proto\landing.proto
} else {
    Write-DebugMsg "Protobuf files are up to date, skipping generation"
}

# Format source code
Write-Build "Formatting Go code..."
go fmt .\...

# Create bin directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "bin" | Out-Null

# Build binaries
Write-Build "Building binaries..."
$serverBin = "bin\server.exe"
$clientBin = "bin\client.exe"

# Build flags
$buildFlags = ""
if ($Release) {
    $buildFlags = "-ldflags='-s -w'"
    Write-Build "Building in release mode (optimized)"
}

# Check if binaries need to be rebuilt
$serverNeedsBuild = $true
$clientNeedsBuild = $true

if (-not $Clean) {
    if (Test-Path $serverBin) {
        $serverTime = (Get-Item $serverBin).LastWriteTime
        $goFiles = Get-ChildItem -Path "server", "common" -Include "*.go" -Recurse
        $newerFiles = $goFiles | Where-Object { $_.LastWriteTime -gt $serverTime }
        if (-not $newerFiles) {
            $serverNeedsBuild = $false
            Write-DebugMsg "Server binary is up to date"
        }
    }
    
    if (Test-Path $clientBin) {
        $clientTime = (Get-Item $clientBin).LastWriteTime
        $goFiles = Get-ChildItem -Path "client", "common" -Include "*.go" -Recurse
        $newerFiles = $goFiles | Where-Object { $_.LastWriteTime -gt $clientTime }
        if (-not $newerFiles) {
            $clientNeedsBuild = $false
            Write-DebugMsg "Client binary is up to date"
        }
    }
}

if ($serverNeedsBuild) {
    Write-Build "Building server..."
    $cmd = "go build $buildFlags -o `"$serverBin`" .\server"
    Invoke-Expression $cmd
}

if ($clientNeedsBuild) {
    Write-Build "Building client..."
    $cmd = "go build $buildFlags -o `"$clientBin`" .\client"
    Invoke-Expression $cmd
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    go test .\...
}

Write-Success "Build completed successfully!"
