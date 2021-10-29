#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
cd ../hello-grpc-rust
export GRPC_SERVER_PORT=8000
export GRPC_HELLO_BACKEND=localhost
export GRPC_HELLO_BACKEND_PORT=8001

cargo run --bin proto-server