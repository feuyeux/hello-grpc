#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ..

# Set port for the server
export GRPC_SERVER_PORT=9997

# Run the server
dotnet run --project HelloServer