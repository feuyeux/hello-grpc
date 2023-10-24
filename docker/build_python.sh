#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e
echo "~~~ build grpc server python ~~~"
mkdir -p hello-grpc-python
cp ../hello-grpc-python/requirements.txt hello-grpc-python
cp -R ../hello-grpc-python/conn hello-grpc-python
cp -R ../hello-grpc-python/server hello-grpc-python
cp ../hello-grpc-python/server_start.sh hello-grpc-python
cp -R ../hello-grpc-python/proto hello-grpc-python
cp ../hello-grpc-python/proto2py.sh hello-grpc-python
docker build -f grpc-server-python.dockerfile -t feuyeux/grpc_server_python:1.0.0 .
rm -rf hello-grpc-python/server
rm -rf hello-grpc-python/server_start.sh
echo

echo "~~~ build grpc client python ~~~"
cp -R ../hello-grpc-python/conn hello-grpc-python
cp -R ../hello-grpc-python/client hello-grpc-python
cp ../hello-grpc-python/client_start.sh hello-grpc-python
docker build -f grpc-client-python.dockerfile -t feuyeux/grpc_client_python:1.0.0 .
rm -rf hello-grpc-python
echo
