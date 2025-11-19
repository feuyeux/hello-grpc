# Build script for PHP gRPC project
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

Write-Build "Building PHP gRPC project..."

# Check for PHP
if (-not (Get-Command php -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "PHP is not installed or not in PATH"
    Write-ErrorMsg "Please install PHP from: https://www.php.net/downloads"
    exit 1
}

# Check for Composer
if (-not (Get-Command composer -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Composer is not installed or not in PATH"
    Write-ErrorMsg "Please install Composer from: https://getcomposer.org/download/"
    exit 1
}

# Display versions
if ($Verbose) {
    Write-Build "PHP version:"
    php --version
    Write-Build "Composer version:"
    composer --version
}

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    Remove-Item -Path "vendor" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "Grpc" -Recurse -Force -ErrorAction SilentlyContinue
}

# Install dependencies
Write-Build "Installing PHP dependencies with Composer..."
if ($Verbose) {
    composer install
} else {
    composer install --quiet
}

# Generate PHP code from proto files
$protoPath = "..\proto\landing.proto"
$pbFile = "Grpc\Landing\LandingServiceClient.php"

$needsProtoGen = $false
if ($Clean -or -not (Test-Path $pbFile)) {
    $needsProtoGen = $true
} elseif ((Get-Item $protoPath).LastWriteTime -gt (Get-Item $pbFile).LastWriteTime) {
    $needsProtoGen = $true
}

if ($needsProtoGen) {
    Write-Build "Generating protobuf code..."
    protoc --proto_path=..\proto `
        --php_out=. `
        --grpc_out=. `
        --plugin=protoc-gen-grpc=vendor\bin\grpc_php_plugin.exe `
        ..\proto\landing.proto
} else {
    Write-DebugMsg "Protobuf files are up to date, skipping generation"
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    if (Test-Path "vendor\bin\phpunit") {
        .\vendor\bin\phpunit
    } else {
        Write-Build "PHPUnit not found, skipping tests"
    }
}

Write-Success "Build completed successfully!"
