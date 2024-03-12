#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

echo "~~~ build grpc base php ~~~"
sh build_alpine_grpc_php.sh

echo "~~~ build grpc server php ~~~"
mkdir -p hello-grpc-php
#
sh ../hello-grpc-php/init.sh
cp -R ../hello-grpc-php/common hello-grpc-php
#
cp ../hello-grpc-php/composer.json hello-grpc-php
cp ../hello-grpc-php/hello_server.php hello-grpc-php
cp ../hello-grpc-php/LandingService.php hello-grpc-php
cp ../hello-grpc-php/log4php_config.xml hello-grpc-php
cp ../hello-grpc-php/server_start.sh hello-grpc-php
cp -R ../hello-grpc-php/proto hello-grpc-php
docker build -f grpc-server-php.dockerfile -t feuyeux/grpc_server_php:1.0.0 .
rm -rf hello-grpc-php/hello_server.php
rm -rf hello-grpc-php/LandingService.php
rm -rf hello-grpc-php/server_start.sh
echo
#
echo "~~~ build grpc client php ~~~"
cp ../hello-grpc-php/hello_client.php hello-grpc-php
cp ../hello-grpc-php/client_start.sh hello-grpc-php
docker build -f grpc-client-php.dockerfile -t feuyeux/grpc_client_php:1.0.0 .
rm -rf hello-grpc-php
echo "done\n"
docker run -ti --rm feuyeux/grpc_server_php:1.0.0 cat /etc/os-release
