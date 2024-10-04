#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

echo "~~~ build grpc server ts ~~~"
mkdir -p hello-grpc-ts
cp ../hello-grpc-ts/tsconfig.json hello-grpc-ts
cp ../hello-grpc-ts/package.json hello-grpc-ts
cp -R ../hello-grpc-ts/common hello-grpc-ts
cp ../hello-grpc-ts/hello_server.ts hello-grpc-ts
docker build -f ts_grpc.dockerfile --target server -t feuyeux/grpc_server_ts:1.0.0 .
echo

echo "~~~ build grpc client ts ~~~"
rm -f hello-grpc-ts/hello_server.ts
cp ../hello-grpc-ts/hello_client.ts hello-grpc-ts
docker build -f ts_grpc.dockerfile --target client -t feuyeux/grpc_client_ts:1.0.0 .
rm -rf hello-grpc-ts
echo
