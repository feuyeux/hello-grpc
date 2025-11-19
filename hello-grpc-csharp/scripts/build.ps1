# Build script for C# gRPC project
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

Write-Build "Building C# gRPC project..."

# Check for .NET
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg ".NET SDK is not installed or not in PATH"
    Write-ErrorMsg "Please install .NET from: https://dotnet.microsoft.com/download"
    exit 1
}

# Display .NET version
if ($Verbose) {
    Write-Build ".NET version:"
    dotnet --version
}

# Build configuration
$buildConfig = if ($Release) { "Release" } else { "Debug" }
Write-DebugMsg "Build configuration: $buildConfig"

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    dotnet clean --configuration $buildConfig
}

# Build the project
Write-Build "Building C# project with dotnet..."
$buildArgs = "build --configuration $buildConfig"
if (-not $Verbose) {
    $buildArgs += " --verbosity quiet"
}

Invoke-Expression "dotnet $buildArgs"

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Build failed"
    exit 1
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    if ($Verbose) {
        dotnet test --configuration $buildConfig
    } else {
        dotnet test --configuration $buildConfig --verbosity quiet
    }
}

Write-Success "Build completed successfully!"
