#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ..

# Set client connection details to connect to the proxy server
export GRPC_SERVER=localhost
export GRPC_SERVER_PORT=8887

# Run the client
dotnet run --project HelloClient