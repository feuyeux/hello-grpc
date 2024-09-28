#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc csharp ~~~"

cp -r ../hello-grpc-csharp .

if [[ "${1}" == "c" ]]; then
  echo "build client"
  docker build -f csharp_grpc.dockerfile --target client -t feuyeux/grpc_client_csharp:1.0.0 .
elif [[ "${1}" == "s" ]]; then
  echo "build server"
  docker build -f csharp_grpc.dockerfile --target server -t feuyeux/grpc_server_csharp:1.0.0 .
else
  echo "build csharp"
  docker build -f csharp_grpc.dockerfile --target build -t feuyeux/grpc_csharp:1.0.0 .
  docker build -f csharp_grpc.dockerfile --target server -t feuyeux/grpc_server_csharp:1.0.0 .
  docker build -f csharp_grpc.dockerfile --target client -t feuyeux/grpc_client_csharp:1.0.0 .
fi

rm -rf hello-grpc-csharp
echo
