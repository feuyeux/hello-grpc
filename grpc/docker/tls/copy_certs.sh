#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

if [ -d /var/hello_grpc/ ]
then
  echo "folder existed"
else
  sudo mkdir -p /var/hello_grpc/
  sudo chown -R han /var/hello_grpc/
fi
ls -l /var/hello_grpc/

if [ -f /var/hello_grpc/server_certs/myssl_root.cer ]
then
  echo "certs existed"
else
  cp -r server_certs /var/hello_grpc/
  cp -r client_certs /var/hello_grpc/
fi
ls -l /var/hello_grpc/server_certs
