# Build script for Python gRPC project
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

Write-Build "Building Python gRPC project..."

# Check for Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "Python is not installed or not in PATH"
    Write-ErrorMsg "Please install Python from: https://www.python.org/downloads/"
    exit 1
}

# Clean if requested
if ($Clean) {
    Write-Build "Cleaning previous build artifacts..."
    Remove-Item -Path "landing_pb2.py" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "landing_pb2_grpc.py" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "__pycache__" -Recurse -Force -ErrorAction SilentlyContinue
}

# Check for virtual environment
if (-not (Test-Path "venv")) {
    Write-Build "Creating virtual environment..."
    python -m venv venv
}

# Activate virtual environment
Write-DebugMsg "Activating virtual environment..."
& "venv\Scripts\Activate.ps1"

# Check if requirements file exists
if (Test-Path "requirements.txt") {
    Write-Build "Installing Python dependencies..."
    if ($Verbose) {
        pip install -r requirements.txt
    } else {
        pip install -q -r requirements.txt
    }
}

# Generate Python code from proto files
$protoPath = "..\proto\landing.proto"
$pbFile = "landing_pb2.py"
$grpcFile = "landing_pb2_grpc.py"

$needsProtoGen = $false
if ($Clean -or -not (Test-Path $pbFile) -or -not (Test-Path $grpcFile)) {
    $needsProtoGen = $true
} elseif ((Get-Item $protoPath).LastWriteTime -gt (Get-Item $pbFile).LastWriteTime) {
    $needsProtoGen = $true
}

if ($needsProtoGen) {
    Write-Build "Generating protobuf code..."
    python -m grpc_tools.protoc `
        -I..\proto `
        --python_out=. `
        --grpc_python_out=. `
        ..\proto\landing.proto
} else {
    Write-DebugMsg "Protobuf files are up to date, skipping generation"
}

# Run tests if requested
if ($Test) {
    Write-Build "Running tests..."
    if (Test-Path "tests") {
        python -m pytest tests\
    } else {
        Write-Build "No tests directory found"
    }
}

Write-Success "Build completed successfully!"
