# Build script for Rust gRPC project
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

Write-Build "Building Rust gRPC project..."

# Check for Rust
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Rust is not installed or not in PATH"
    Write-ErrorMsg "Please install Rust from: https://www.rust-lang.org/tools/install"
    exit 1
}

# Display Rust version
if ($Verbose) {
    Write-Build "Rust version:"
    rustc --version
    cargo --version
}

# Build command
$cargoArgs = "build"
if ($Release) {
    $cargoArgs += " --release"
    Write-Build "Building in release mode (optimized)"
}

if ($Verbose) {
    $cargoArgs += " --verbose"
}

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    cargo clean
}

# Build the project
Write-Build "Building Rust project with Cargo..."
Invoke-Expression "cargo $cargoArgs"

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Build failed"
    exit 1
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    if ($Verbose) {
        cargo test --verbose
    } else {
        cargo test
    }
}

Write-Success "Build completed successfully!"
