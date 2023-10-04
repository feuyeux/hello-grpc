#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

swiftformat --indent 4 --swiftversion 5.8 --exclude "**/*.grpc.swift,**/*.pb.swift" .