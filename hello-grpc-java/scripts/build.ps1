# Build script for Java gRPC project
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

Write-Build "Building Java gRPC project..."

# Check for Java
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Java is not installed or not in PATH"
    Write-ErrorMsg "Please install Java from: https://adoptium.net/"
    exit 1
}

# Check for Maven
if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Maven is not installed or not in PATH"
    Write-ErrorMsg "Please install Maven from: https://maven.apache.org/download.cgi"
    exit 1
}

# Display versions
if ($Verbose) {
    Write-Build "Java version:"
    java -version
    Write-Build "Maven version:"
    mvn -version
}

# Check if artifacts need to be rebuilt
$serverJar = "target\hello-grpc-java-server.jar"
$clientJar = "target\hello-grpc-java-client.jar"
$pomFile = "pom.xml"

$needsBuild = $false
if ($Clean -or -not (Test-Path $serverJar) -or -not (Test-Path $clientJar)) {
    $needsBuild = $true
} elseif ((Get-Item $pomFile).LastWriteTime -gt (Get-Item $serverJar).LastWriteTime) {
    $needsBuild = $true
} else {
    $javaFiles = Get-ChildItem -Path "src" -Include "*.java" -Recurse
    $newerFiles = $javaFiles | Where-Object { $_.LastWriteTime -gt (Get-Item $serverJar).LastWriteTime }
    if ($newerFiles) {
        $needsBuild = $true
    }
}

if ($needsBuild) {
    Write-Build "Building Java project with Maven..."
    
    # Build command
    $mvnArgs = "install"
    if (-not $Test) {
        $mvnArgs += " -DskipTests"
    }
    
    if ($Clean) {
        Write-Build "Cleaning previous build artifacts..."
        $mvnArgs = "clean " + $mvnArgs
    }
    
    if (-not $Verbose) {
        $mvnArgs += " -q"
    }
    
    $cmd = "mvn $mvnArgs"
    Invoke-Expression $cmd
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Build failed"
        exit 1
    }
} else {
    Write-DebugMsg "Java project is up to date, skipping build"
}

# Run tests if requested and not already run
if ($Test -and -not $needsBuild) {
    Write-Build "Running tests..."
    mvn test
}

Write-Success "Build completed successfully!"
