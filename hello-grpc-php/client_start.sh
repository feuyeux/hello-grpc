#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

php -d extension=grpc.so hello_client.php