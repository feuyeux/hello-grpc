# Build script for Dart gRPC project
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

Write-Build "Building Dart gRPC project..."

# Check for Dart
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Dart is not installed or not in PATH"
    Write-ErrorMsg "Please install Dart from: https://dart.dev/get-dart"
    exit 1
}

# Display Dart version
if ($Verbose) {
    Write-Build "Dart version:"
    dart --version
}

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    dart pub cache clean
    Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
}

# Get dependencies
Write-Build "Getting Dart dependencies..."
if ($Verbose) {
    dart pub get
} else {
    dart pub get | Out-Null
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    if ($Verbose) {
        dart test
    } else {
        dart test
    }
}

Write-Success "Build completed successfully!"
