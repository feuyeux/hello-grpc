#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

docker images | grep composer

echo "~~~ build alpine grpc php ~~~"
docker build -f php_grpc_base.dockerfile -t feuyeux/grpc_php_base:1.0.0 .
docker run -it --rm feuyeux/grpc_php_base:1.0.0 composer --version
