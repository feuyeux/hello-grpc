# Build script for C++ gRPC project
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

Write-Build "Building C++ gRPC project..."

# Check for Bazel
if (-not (Get-Command bazel -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Bazel is not installed or not in PATH"
    Write-ErrorMsg "Please install Bazel from: https://bazel.build/install"
    exit 1
}

# Display Bazel version
if ($Verbose) {
    Write-Build "Bazel version:"
    bazel version
}

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    bazel clean
}

# Build configuration
$buildConfig = if ($Release) { "opt" } else { "fastbuild" }
Write-DebugMsg "Build configuration: $buildConfig"

# Build command
$bazelArgs = "build --compilation_mode=$buildConfig"
if ($Verbose) {
    $bazelArgs += " --verbose_failures"
}

# Build all targets
Write-Build "Building C++ project with Bazel..."
$targets = @("//server:proto_server", "//client:proto_client")
foreach ($target in $targets) {
    Write-Build "Building $target..."
    Invoke-Expression "bazel $bazelArgs $target"
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Build failed for $target"
        exit 1
    }
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    if ($Verbose) {
        bazel test --verbose_failures //tests:all
    } else {
        bazel test //tests:all
    }
}

Write-Success "Build completed successfully!"
