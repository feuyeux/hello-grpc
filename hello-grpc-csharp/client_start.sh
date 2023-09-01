#!/usr/bin/env sh
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit
cd HelloClient || exit
dotnet clean
dotnet run
