#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e
echo "~~~ build grpc server python ~~~"
mkdir -p py
cp ../hello-grpc-python/requirements.txt py
cp -R ../hello-grpc-python/conn py
cp -R ../hello-grpc-python/server py
cp ../hello-grpc-python/server_start.sh py
cp -R ../proto py
cp ../hello-grpc-python/proto2py.sh py
docker build -f grpc-server-python.dockerfile -t feuyeux/grpc_server_python:1.0.0 .
rm -rf py/server
rm -rf py/server_start.sh
echo

echo "~~~ build grpc client python ~~~"
cp -R ../hello-grpc-python/conn py
cp -R ../hello-grpc-python/client py
cp ../hello-grpc-python/client_start.sh py
docker build -f grpc-client-python.dockerfile -t feuyeux/grpc_client_python:1.0.0 .
rm -rf py
echo