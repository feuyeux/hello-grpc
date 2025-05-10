#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ..

# Set port for the proxy server
export GRPC_SERVER_PORT=8887

# Set backend connection details
export GRPC_HELLO_BACKEND=localhost
export GRPC_HELLO_BACKEND_PORT=9997

# Run the proxy server
dotnet run --project HelloServer