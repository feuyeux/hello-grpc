#!/bin/bash

# Generate gRPC-compatible TLS certificates
# This script creates a CA and server certificates suitable for gRPC

set -e

CERT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_CERT_DIR="$CERT_DIR/server_certs"
CLIENT_CERT_DIR="$CERT_DIR/client_certs"

echo "Generating gRPC-compatible certificates..."
echo "Certificate directory: $CERT_DIR"

# Create directories if they don't exist
mkdir -p "$SERVER_CERT_DIR"
mkdir -p "$CLIENT_CERT_DIR"

# 1. Generate CA private key
echo "1. Generating CA private key..."
openssl genrsa -out "$CERT_DIR/ca.key" 4096

# 2. Generate CA certificate
echo "2. Generating CA certificate..."
openssl req -new -x509 -days 3650 -key "$CERT_DIR/ca.key" -out "$CERT_DIR/ca.crt" \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=HelloGRPC/OU=CA/CN=HelloGRPC CA"

# 3. Generate server private key
echo "3. Generating server private key..."
openssl genrsa -out "$SERVER_CERT_DIR/private.key" 4096

# 4. Generate server certificate signing request (CSR)
echo "4. Generating server CSR..."
openssl req -new -key "$SERVER_CERT_DIR/private.key" -out "$SERVER_CERT_DIR/server.csr" \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=HelloGRPC/OU=Server/CN=hello.grpc.io"

# 5. Create server certificate extensions file
echo "5. Creating server certificate extensions..."
cat > "$SERVER_CERT_DIR/server.ext" << EOF
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
EOF

# 6. Generate server certificate signed by CA
echo "6. Generating server certificate..."
openssl x509 -req -in "$SERVER_CERT_DIR/server.csr" \
  -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
  -out "$SERVER_CERT_DIR/cert.pem" -days 3650 \
  -extfile "$SERVER_CERT_DIR/server.ext"

# 7. Create full certificate chain
echo "7. Creating full certificate chain..."
cat "$SERVER_CERT_DIR/cert.pem" "$CERT_DIR/ca.crt" > "$SERVER_CERT_DIR/full_chain.pem"

# 8. Copy CA certificate to server and client directories
echo "8. Copying CA certificate..."
cp "$CERT_DIR/ca.crt" "$SERVER_CERT_DIR/myssl_root.cer"
cp "$CERT_DIR/ca.crt" "$CLIENT_CERT_DIR/myssl_root.cer"
cp "$SERVER_CERT_DIR/cert.pem" "$CLIENT_CERT_DIR/cert.pem"
cp "$SERVER_CERT_DIR/full_chain.pem" "$CLIENT_CERT_DIR/full_chain.pem"
cp "$SERVER_CERT_DIR/private.key" "$CLIENT_CERT_DIR/private.key"

# 9. Verify the certificate
echo "9. Verifying server certificate..."
openssl verify -CAfile "$CERT_DIR/ca.crt" "$SERVER_CERT_DIR/cert.pem"

echo ""
echo "✅ Certificate generation complete!"
echo ""
echo "Generated files:"
echo "  CA Certificate: $CERT_DIR/ca.crt"
echo "  Server Certificate: $SERVER_CERT_DIR/cert.pem"
echo "  Server Private Key: $SERVER_CERT_DIR/private.key"
echo "  Full Chain: $SERVER_CERT_DIR/full_chain.pem"
echo ""
echo "Certificate details:"
openssl x509 -in "$SERVER_CERT_DIR/cert.pem" -text -noout | grep -A 2 "Subject:\|Issuer:\|DNS:\|IP:"
