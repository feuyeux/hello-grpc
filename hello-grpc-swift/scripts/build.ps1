# Build script for Swift gRPC project
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

Write-Build "Building Swift gRPC project..."

# Check for Swift
if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Swift is not installed or not in PATH"
    Write-ErrorMsg "Please install Swift from: https://swift.org/download/"
    exit 1
}

# Display Swift version
if ($Verbose) {
    Write-Build "Swift version:"
    swift --version
}

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    swift package clean
}

# Build configuration
$buildConfig = if ($Release) { "release" } else { "debug" }
Write-DebugMsg "Build configuration: $buildConfig"

# Build command
$buildArgs = "build --configuration $buildConfig"
if ($Verbose) {
    $buildArgs += " --verbose"
}

# Build the project
Write-Build "Building Swift project with SwiftPM..."
Invoke-Expression "swift $buildArgs"

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Build failed"
    exit 1
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    if ($Verbose) {
        swift test --verbose
    } else {
        swift test
    }
}

Write-Success "Build completed successfully!"
