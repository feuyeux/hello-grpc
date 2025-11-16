$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot
Set-Location HelloClient

Write-Host "Cleaning C# gRPC Client..." -ForegroundColor Cyan
dotnet clean

Write-Host ""
Write-Host "Starting C# gRPC Client with TLS..." -ForegroundColor Green
Write-Host ""

# Get the absolute path to client certs
$certBasePath = Join-Path $PSScriptRoot "..\docker\tls\client_certs"
$certBasePath = Resolve-Path $certBasePath

# Enable TLS
$env:GRPC_HELLO_SECURE = "Y"
$env:CERT_BASE_PATH = $certBasePath

# Set server address to connect to
$env:GRPC_SERVER = "localhost"
$env:GRPC_SERVER_PORT = "9996"

Write-Host "Certificate path: $certBasePath" -ForegroundColor Yellow
Write-Host "TLS enabled: $($env:GRPC_HELLO_SECURE)" -ForegroundColor Yellow
Write-Host "Connecting to: $($env:GRPC_SERVER):$($env:GRPC_SERVER_PORT)" -ForegroundColor Yellow
Write-Host ""

dotnet run -- --addr=localhost:9996
