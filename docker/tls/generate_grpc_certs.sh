#!/usr/bin/env bash
# Generate gRPC-compatible TLS certificates
# This script creates a CA and server/client certificates suitable for gRPC
# Aligned with generate_grpc_certs.ps1

set -e

# Colors for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR"
SERVER_CERT_DIR="$CERT_DIR/server_certs"
CLIENT_CERT_DIR="$CERT_DIR/client_certs"

# Parse command line arguments
COPY_TO_VAR=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy-to-var)
      COPY_TO_VAR=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Generate gRPC-compatible TLS certificates"
      echo ""
      echo "Options:"
      echo "  --copy-to-var    Also copy certificates to /var/hello_grpc/"
      echo "  --help, -h       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help to see available options"
      exit 1
      ;;
  esac
done

echo -e "${GREEN}Generating gRPC-compatible certificates...${NC}"
echo "Certificate directory: $CERT_DIR"

# Create directories if they don't exist
mkdir -p "$SERVER_CERT_DIR"
mkdir -p "$CLIENT_CERT_DIR"

# 1. Generate CA private key
echo -e "\n${CYAN}1. Generating CA private key...${NC}"
openssl genrsa -out "$CERT_DIR/ca.key" 4096

# 2. Generate CA certificate
echo -e "${CYAN}2. Generating CA certificate...${NC}"
openssl req -new -x509 -days 3650 -key "$CERT_DIR/ca.key" -out "$CERT_DIR/ca.crt" \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=HelloGRPC/OU=CA/CN=HelloGRPC CA"

# 3. Generate server private key
echo -e "${CYAN}3. Generating server private key...${NC}"
openssl genrsa -out "$SERVER_CERT_DIR/private.key" 4096

# 4. Generate server certificate signing request (CSR)
echo -e "${CYAN}4. Generating server CSR...${NC}"
openssl req -new -key "$SERVER_CERT_DIR/private.key" -out "$SERVER_CERT_DIR/server.csr" \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=HelloGRPC/OU=Server/CN=hello.grpc.io"

# 5. Create server certificate extensions file
echo -e "${CYAN}5. Creating server certificate extensions...${NC}"
cat > "$SERVER_CERT_DIR/server.ext" <<EOF
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
echo -e "${CYAN}6. Generating server certificate...${NC}"
openssl x509 -req -in "$SERVER_CERT_DIR/server.csr" \
  -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
  -out "$SERVER_CERT_DIR/cert.pem" -days 3650 \
  -extfile "$SERVER_CERT_DIR/server.ext"

# 7. Create full certificate chain
echo -e "${CYAN}7. Creating full certificate chain...${NC}"
cat "$SERVER_CERT_DIR/cert.pem" "$CERT_DIR/ca.crt" > "$SERVER_CERT_DIR/full_chain.pem"

# 8. Generate client private key
echo -e "${CYAN}8. Generating client private key...${NC}"
openssl genrsa -out "$CLIENT_CERT_DIR/private.key" 4096

# 9. Generate client certificate signing request (CSR)
echo -e "${CYAN}9. Generating client CSR...${NC}"
openssl req -new -key "$CLIENT_CERT_DIR/private.key" -out "$CLIENT_CERT_DIR/client.csr" \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=HelloGRPC/OU=Client/CN=hello.grpc.client"

# 10. Create client certificate extensions file
echo -e "${CYAN}10. Creating client certificate extensions...${NC}"
cat > "$CLIENT_CERT_DIR/client.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

# 11. Generate client certificate signed by CA
echo -e "${CYAN}11. Generating client certificate...${NC}"
openssl x509 -req -in "$CLIENT_CERT_DIR/client.csr" \
  -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
  -out "$CLIENT_CERT_DIR/cert.pem" -days 3650 \
  -extfile "$CLIENT_CERT_DIR/client.ext"

# 12. Create client full certificate chain
echo -e "${CYAN}12. Creating client full certificate chain...${NC}"
cat "$CLIENT_CERT_DIR/cert.pem" "$CERT_DIR/ca.crt" > "$CLIENT_CERT_DIR/full_chain.pem"

# 13. Convert private keys to PKCS8 format (for Java compatibility)
echo -e "${CYAN}13. Converting private keys to PKCS8 format...${NC}"
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt \
  -in "$SERVER_CERT_DIR/private.key" -out "$SERVER_CERT_DIR/private.pkcs8.key"
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt \
  -in "$CLIENT_CERT_DIR/private.key" -out "$CLIENT_CERT_DIR/private.pkcs8.key"

# 14. Copy CA certificate to both directories
echo -e "${CYAN}14. Copying CA certificate...${NC}"
cp "$CERT_DIR/ca.crt" "$SERVER_CERT_DIR/myssl_root.cer"
cp "$CERT_DIR/ca.crt" "$CLIENT_CERT_DIR/myssl_root.cer"

# 15. Create symbolic links for convenience
echo -e "${CYAN}15. Creating symbolic links...${NC}"
ln -sf cert.pem "$SERVER_CERT_DIR/server.crt" 2>/dev/null || true
ln -sf cert.pem "$CLIENT_CERT_DIR/client.crt" 2>/dev/null || true
ln -sf private.key "$CLIENT_CERT_DIR/client.key" 2>/dev/null || true

# 16. Verify the certificates
echo -e "${CYAN}16. Verifying certificates...${NC}"
echo "Server certificate:"
openssl verify -CAfile "$CERT_DIR/ca.crt" "$SERVER_CERT_DIR/cert.pem"
echo "Client certificate:"
openssl verify -CAfile "$CERT_DIR/ca.crt" "$CLIENT_CERT_DIR/cert.pem"

# 17. Copy to /var/hello_grpc if requested
if [ "$COPY_TO_VAR" = true ]; then
  echo -e "\n${CYAN}17. Copying certificates to /var/hello_grpc/...${NC}"
  
  VAR_SERVER_DIR="/var/hello_grpc/server_certs"
  VAR_CLIENT_DIR="/var/hello_grpc/client_certs"
  
  sudo mkdir -p "$VAR_SERVER_DIR"
  sudo mkdir -p "$VAR_CLIENT_DIR"
  
  # Copy all files from server_certs
  sudo cp "$SERVER_CERT_DIR/cert.pem" "$VAR_SERVER_DIR/"
  sudo cp "$SERVER_CERT_DIR/private.key" "$VAR_SERVER_DIR/"
  sudo cp "$SERVER_CERT_DIR/private.pkcs8.key" "$VAR_SERVER_DIR/"
  sudo cp "$SERVER_CERT_DIR/full_chain.pem" "$VAR_SERVER_DIR/"
  sudo cp "$SERVER_CERT_DIR/myssl_root.cer" "$VAR_SERVER_DIR/"
  
  # Copy all files from client_certs
  sudo cp "$CLIENT_CERT_DIR/cert.pem" "$VAR_CLIENT_DIR/"
  sudo cp "$CLIENT_CERT_DIR/private.key" "$VAR_CLIENT_DIR/"
  sudo cp "$CLIENT_CERT_DIR/private.pkcs8.key" "$VAR_CLIENT_DIR/"
  sudo cp "$CLIENT_CERT_DIR/full_chain.pem" "$VAR_CLIENT_DIR/"
  sudo cp "$CLIENT_CERT_DIR/myssl_root.cer" "$VAR_CLIENT_DIR/"
  
  # Set proper permissions
  sudo chmod 644 "$VAR_SERVER_DIR"/*.{pem,cer} 2>/dev/null || true
  sudo chmod 600 "$VAR_SERVER_DIR"/private.* 2>/dev/null || true
  sudo chmod 644 "$VAR_CLIENT_DIR"/*.{pem,cer} 2>/dev/null || true
  sudo chmod 600 "$VAR_CLIENT_DIR"/private.* 2>/dev/null || true
  
  echo -e "${GREEN}Certificates copied to /var/hello_grpc/${NC}"
fi

echo -e "\n${GREEN}✅ Certificate generation complete!${NC}"
echo -e "\n${YELLOW}Generated files:${NC}"
echo "  CA Certificate: $CERT_DIR/ca.crt"
echo "  Server Certificate: $SERVER_CERT_DIR/cert.pem"
echo "  Server Private Key: $SERVER_CERT_DIR/private.key"
echo "  Full Chain: $SERVER_CERT_DIR/full_chain.pem"

echo -e "\n${YELLOW}Certificate details:${NC}"
openssl x509 -in "$SERVER_CERT_DIR/cert.pem" -text -noout | grep -E "Subject:|Issuer:|DNS:|IP:" || true
