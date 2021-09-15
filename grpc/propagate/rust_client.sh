#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ../hello-grpc-rust
export GRPC_SERVER=localhost
export GRPC_SERVER_PORT=8000

cargo run --bin proto-client