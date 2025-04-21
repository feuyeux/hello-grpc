#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS implementation
  if [ -d /var/hello_grpc/ ]; then
    echo "folder existed"
    # sudo chown -R "$(whoami)" /var/hello_grpc/
  else
    sudo mkdir -p /var/hello_grpc/
    sudo chown -R "$(whoami)" /var/hello_grpc/
  fi
  ls -l /var/hello_grpc/

  if [ -f /var/hello_grpc/server_certs/myssl_root.cer ]; then
    echo "certs existed"
  else
    cp -r server_certs /var/hello_grpc/
    cp -r client_certs /var/hello_grpc/
  fi
  ls -l /var/hello_grpc/server_certs

elif [[ "$OSTYPE" == "msys" ]]; then
  # Windows implementation
  if [ -d /d/garden/var/hello_grpc/ ]; then
    echo "folder existed"
  else
    mkdir -p /d/garden/var/hello_grpc/
  fi
  ls -l /d/garden/var/hello_grpc/

  if [ -f /d/garden/var/hello_grpc/server_certs/myssl_root.cer ]; then
    echo "certs existed"
  else
    cp -r server_certs /d/garden/var/hello_grpc/
    cp -r client_certs /d/garden/var/hello_grpc/
  fi
  ls -l /d/garden/var/hello_grpc/server_certs
else
  echo "Unsupported OS"
  exit 1
fi
