#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ..
export GRPC_SERVER_PORT=9997
gradle :server:ProtoServer