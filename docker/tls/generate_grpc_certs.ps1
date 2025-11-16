# Generate gRPC-compatible TLS certificates
# This script creates a CA and server certificates suitable for gRPC

$ErrorActionPreference = "Stop"

$CERT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SERVER_CERT_DIR = Join-Path $CERT_DIR "server_certs"
$CLIENT_CERT_DIR = Join-Path $CERT_DIR "client_certs"

Write-Host "Generating gRPC-compatible certificates..." -ForegroundColor Green
Write-Host "Certificate directory: $CERT_DIR"

# Create directories if they don't exist
New-Item -ItemType Directory -Force -Path $SERVER_CERT_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $CLIENT_CERT_DIR | Out-Null

# 1. Generate CA private key
Write-Host "`n1. Generating CA private key..." -ForegroundColor Cyan
openssl genrsa -out "$CERT_DIR/ca.key" 4096

# 2. Generate CA certificate
Write-Host "2. Generating CA certificate..." -ForegroundColor Cyan
openssl req -new -x509 -days 3650 -key "$CERT_DIR/ca.key" -out "$CERT_DIR/ca.crt" `
  -subj "/C=CN/ST=Beijing/L=Beijing/O=HelloGRPC/OU=CA/CN=HelloGRPC CA"

# 3. Generate server private key
Write-Host "3. Generating server private key..." -ForegroundColor Cyan
openssl genrsa -out "$SERVER_CERT_DIR/private.key" 4096

# 4. Generate server certificate signing request (CSR)
Write-Host "4. Generating server CSR..." -ForegroundColor Cyan
openssl req -new -key "$SERVER_CERT_DIR/private.key" -out "$SERVER_CERT_DIR/server.csr" `
  -subj "/C=CN/ST=Beijing/L=Beijing/O=HelloGRPC/OU=Server/CN=hello.grpc.io"

# 5. Create server certificate extensions file
Write-Host "5. Creating server certificate extensions..." -ForegroundColor Cyan
$extContent = @"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = hello.grpc.io
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
"@
Set-Content -Path "$SERVER_CERT_DIR/server.ext" -Value $extContent

# 6. Generate server certificate signed by CA
Write-Host "6. Generating server certificate..." -ForegroundColor Cyan
openssl x509 -req -in "$SERVER_CERT_DIR/server.csr" `
  -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial `
  -out "$SERVER_CERT_DIR/cert.pem" -days 3650 `
  -extfile "$SERVER_CERT_DIR/server.ext"

# 7. Create full certificate chain
Write-Host "7. Creating full certificate chain..." -ForegroundColor Cyan
Get-Content "$SERVER_CERT_DIR/cert.pem", "$CERT_DIR/ca.crt" | Set-Content "$SERVER_CERT_DIR/full_chain.pem"

# 8. Copy CA certificate to server and client directories
Write-Host "8. Copying CA certificate..." -ForegroundColor Cyan
Copy-Item "$CERT_DIR/ca.crt" "$SERVER_CERT_DIR/myssl_root.cer" -Force
Copy-Item "$CERT_DIR/ca.crt" "$CLIENT_CERT_DIR/myssl_root.cer" -Force
Copy-Item "$SERVER_CERT_DIR/cert.pem" "$CLIENT_CERT_DIR/cert.pem" -Force
Copy-Item "$SERVER_CERT_DIR/full_chain.pem" "$CLIENT_CERT_DIR/full_chain.pem" -Force
Copy-Item "$SERVER_CERT_DIR/private.key" "$CLIENT_CERT_DIR/private.key" -Force

# 9. Verify the certificate
Write-Host "9. Verifying server certificate..." -ForegroundColor Cyan
openssl verify -CAfile "$CERT_DIR/ca.crt" "$SERVER_CERT_DIR/cert.pem"

Write-Host "`n✅ Certificate generation complete!" -ForegroundColor Green
Write-Host "`nGenerated files:" -ForegroundColor Yellow
Write-Host "  CA Certificate: $CERT_DIR/ca.crt"
Write-Host "  Server Certificate: $SERVER_CERT_DIR/cert.pem"
Write-Host "  Server Private Key: $SERVER_CERT_DIR/private.key"
Write-Host "  Full Chain: $SERVER_CERT_DIR/full_chain.pem"

Write-Host "`nCertificate details:" -ForegroundColor Yellow
openssl x509 -in "$SERVER_CERT_DIR/cert.pem" -text -noout | Select-String -Pattern "Subject:|Issuer:|DNS:|IP:"
