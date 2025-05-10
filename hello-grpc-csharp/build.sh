#!/bin/bash
# Build script for C# gRPC project
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Building C# gRPC project..."

# Check if .NET SDK is installed
if ! command -v dotnet &> /dev/null; then
    echo "The .NET SDK is not installed. Please install it from https://dotnet.microsoft.com/download"
    exit 1
fi

# Display .NET version
echo "Using .NET version:"
dotnet --version

# Check if we need to clean
if [ "$1" == "--clean" ]; then
    echo "Cleaning previous build artifacts..."
    dotnet clean HelloGrpc.sln
    # Also remove bin and obj directories
    find . -name "bin" -o -name "obj" | xargs rm -rf
    shift
fi

# Check if any project files have been modified since the last build
SOLUTION_FILE="HelloGrpc.sln"
SERVER_PROJECT="HelloServer/HelloServer.csproj"
CLIENT_PROJECT="HelloClient/HelloClient.csproj"
SERVER_BIN="HelloServer/bin/Debug/net9.0/HelloServer.dll"
CLIENT_BIN="HelloClient/bin/Debug/net9.0/HelloClient.dll"

NEEDS_BUILD=false

# Check if binaries exist
if [ ! -f "$SERVER_BIN" ] || [ ! -f "$CLIENT_BIN" ]; then
    NEEDS_BUILD=true
elif [ "$SOLUTION_FILE" -nt "$SERVER_BIN" ] || [ "$SERVER_PROJECT" -nt "$SERVER_BIN" ] || \
     [ "$SOLUTION_FILE" -nt "$CLIENT_BIN" ] || [ "$CLIENT_PROJECT" -nt "$CLIENT_BIN" ]; then
    NEEDS_BUILD=true
elif [ -n "$(find . -name "*.cs" -newer "$SERVER_BIN" -o -name "*.cs" -newer "$CLIENT_BIN" 2>/dev/null)" ]; then
    NEEDS_BUILD=true
fi

if [ "$NEEDS_BUILD" = true ]; then
    echo "Building C# solution..."
    dotnet build HelloGrpc.sln "$@"
else
    echo "C# project is up to date, skipping build"
fi

echo "C# gRPC project built successfully!"
