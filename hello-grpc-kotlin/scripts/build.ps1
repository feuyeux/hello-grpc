# Build script for Kotlin gRPC project
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

Write-Build "Building Kotlin gRPC project..."

# Check for Java
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Java is not installed or not in PATH"
    Write-ErrorMsg "Please install Java from: https://adoptium.net/"
    exit 1
}

# Display Java version
if ($Verbose) {
    Write-Build "Java version:"
    java -version
}

# Determine Gradle wrapper
$gradleCmd = if (Test-Path "gradlew.bat") { ".\gradlew.bat" } else { "gradle" }

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    & $gradleCmd clean
}

# Build command
$gradleArgs = "build"
if (-not $Test) {
    $gradleArgs = "build -x test"
}

if (-not $Verbose) {
    $gradleArgs += " -q"
}

# Build the project
Write-Build "Building Kotlin project with Gradle..."
& $gradleCmd $gradleArgs.Split()

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Build failed"
    exit 1
}

# Run tests if requested and not already run
if ($Test -and $Clean) {
    Write-Build "Running tests..."
    & $gradleCmd test
}

Write-Success "Build completed successfully!"
