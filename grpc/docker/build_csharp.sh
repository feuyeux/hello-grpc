#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc csharp ~~~"
cd ..
cp -r hello-grpc-csharp docker/
cd docker
docker build -f grpc-csharp.dockerfile -t feuyeux/grpc_csharp:1.0.0 .
rm -rf hello-grpc-csharp
echo
