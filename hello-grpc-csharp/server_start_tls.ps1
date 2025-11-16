$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot
Set-Location HelloServer

Write-Host "Cleaning and building C# gRPC Server..." -ForegroundColor Cyan
dotnet clean
dotnet build

Write-Host ""
Write-Host "Starting C# gRPC Server with TLS..." -ForegroundColor Green
Write-Host ""

# Get the absolute path to server certs
$certBasePath = Join-Path $PSScriptRoot "..\docker\tls\server_certs"
$certBasePath = Resolve-Path $certBasePath

# Enable TLS
$env:GRPC_HELLO_SECURE = "Y"
$env:CERT_BASE_PATH = $certBasePath

# Set server address
$env:GRPC_SERVER = "0.0.0.0"
$env:GRPC_SERVER_PORT = "9996"

Write-Host "Certificate path: $certBasePath" -ForegroundColor Yellow
Write-Host "TLS enabled: $($env:GRPC_HELLO_SECURE)" -ForegroundColor Yellow
Write-Host "Server address: $($env:GRPC_SERVER):$($env:GRPC_SERVER_PORT)" -ForegroundColor Yellow
Write-Host ""

dotnet run -- --addr=0.0.0.0:9996
