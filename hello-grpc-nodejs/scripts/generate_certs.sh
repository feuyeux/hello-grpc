#!/bin/bash

# Certificate generation script for gRPC with proper Extended Key Usage
# This script generates:
# 1. Root CA certificate
# 2. Intermediate CA certificate (with proper Extended Key Usage)
# 3. Server certificate for hello.grpc.io

set -e

# Configuration
CERT_DIR="/var/hello_grpc"
SERVER_CERT_DIR="${CERT_DIR}/server_certs"
CLIENT_CERT_DIR="${CERT_DIR}/client_certs"
TEMP_DIR="/tmp/grpc_certs_$$"

# Create directories
echo "Creating certificate directories..."
sudo mkdir -p "${SERVER_CERT_DIR}"
sudo mkdir -p "${CLIENT_CERT_DIR}"
mkdir -p "${TEMP_DIR}"

cd "${TEMP_DIR}"

# ============================================
# 1. Generate Root CA
# ============================================
echo "Generating Root CA..."

cat > root_ca.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = CN
O = MySSL
OU = MySSL Test Root - For test use only
CN = MySSL.com

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
EOF

# Generate root CA private key
openssl genrsa -out root_ca.key 2048

# Generate root CA certificate (self-signed, valid for 10 years)
openssl req -new -x509 -days 3650 -key root_ca.key -out root_ca.crt -config root_ca.cnf

echo "Root CA generated successfully"

# ============================================
# 2. Generate Intermediate CA
# ============================================
echo "Generating Intermediate CA..."

cat > intermediate_ca.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = CN
O = MySSL
OU = MySSL Test RSA - For test use only
CN = MySSL.com

[v3_intermediate_ca]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,keyCertSign,cRLSign,digitalSignature
extendedKeyUsage = serverAuth,clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

# Generate intermediate CA private key
openssl genrsa -out intermediate_ca.key 2048

# Generate intermediate CA CSR
openssl req -new -key intermediate_ca.key -out intermediate_ca.csr -config intermediate_ca.cnf

# Sign intermediate CA certificate with root CA (valid for 5 years)
openssl x509 -req -days 1825 -in intermediate_ca.csr \
    -CA root_ca.crt -CAkey root_ca.key -CAcreateserial \
    -out intermediate_ca.crt -extfile intermediate_ca.cnf -extensions v3_intermediate_ca

echo "Intermediate CA generated successfully"

# ============================================
# 3. Generate Server Certificate
# ============================================
echo "Generating Server Certificate..."

cat > server.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = CN
CN = hello.grpc.io

[v3_req]
basicConstraints = CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = hello.grpc.io
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# Generate server private key
openssl genrsa -out server.key 2048

# Generate server CSR
openssl req -new -key server.key -out server.csr -config server.cnf

# Sign server certificate with intermediate CA (valid for 1 year)
openssl x509 -req -days 365 -in server.csr \
    -CA intermediate_ca.crt -CAkey intermediate_ca.key -CAcreateserial \
    -out server.crt -extfile server.cnf -extensions v3_req

echo "Server certificate generated successfully"

# ============================================
# 4. Create certificate chain files
# ============================================
echo "Creating certificate chain files..."

# Full chain: server cert + intermediate CA cert
cat server.crt intermediate_ca.crt > full_chain.pem

# Complete chain: server cert + intermediate CA cert + root CA cert
cat server.crt intermediate_ca.crt root_ca.crt > complete_chain.pem

# Convert server key to PKCS8 format
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt \
    -in server.key -out server.pkcs8.key

# ============================================
# 5. Copy certificates to target directories
# ============================================
echo "Installing certificates..."

# Server certificates
sudo cp server.crt "${SERVER_CERT_DIR}/cert.pem"
sudo cp server.key "${SERVER_CERT_DIR}/private.key"
sudo cp server.pkcs8.key "${SERVER_CERT_DIR}/private.pkcs8.key"
sudo cp full_chain.pem "${SERVER_CERT_DIR}/full_chain.pem"
sudo cp root_ca.crt "${SERVER_CERT_DIR}/myssl_root.cer"

# Client certificates (only needs root CA for verification)
sudo cp root_ca.crt "${CLIENT_CERT_DIR}/myssl_root.cer"

# Set proper permissions
sudo chmod 644 "${SERVER_CERT_DIR}/cert.pem"
sudo chmod 600 "${SERVER_CERT_DIR}/private.key"
sudo chmod 600 "${SERVER_CERT_DIR}/private.pkcs8.key"
sudo chmod 644 "${SERVER_CERT_DIR}/full_chain.pem"
sudo chmod 644 "${SERVER_CERT_DIR}/myssl_root.cer"
sudo chmod 644 "${CLIENT_CERT_DIR}/myssl_root.cer"

# ============================================
# 6. Verify certificates
# ============================================
echo ""
echo "Verifying certificates..."

echo "1. Verifying certificate chain:"
openssl verify -CAfile root_ca.crt -untrusted intermediate_ca.crt server.crt

echo ""
echo "2. Verifying for SSL server purpose:"
openssl verify -purpose sslserver -CAfile root_ca.crt -untrusted intermediate_ca.crt server.crt

echo ""
echo "3. Server certificate details:"
openssl x509 -in server.crt -noout -subject -issuer -dates -ext subjectAltName,extendedKeyUsage

echo ""
echo "4. Intermediate CA certificate details:"
openssl x509 -in intermediate_ca.crt -noout -subject -issuer -ext basicConstraints,keyUsage,extendedKeyUsage

# ============================================
# 7. Cleanup
# ============================================
echo ""
echo "Cleaning up temporary files..."
cd /
rm -rf "${TEMP_DIR}"

echo ""
echo "✅ Certificate generation completed successfully!"
echo ""
echo "Generated certificates:"
echo "  Server certificates: ${SERVER_CERT_DIR}/"
echo "    - cert.pem (server certificate)"
echo "    - private.key (server private key)"
echo "    - private.pkcs8.key (server private key in PKCS8 format)"
echo "    - full_chain.pem (server cert + intermediate CA)"
echo "    - myssl_root.cer (root CA certificate)"
echo ""
echo "  Client certificates: ${CLIENT_CERT_DIR}/"
echo "    - myssl_root.cer (root CA certificate for verification)"
echo ""
echo "You can now restart your gRPC server and client with TLS enabled."
