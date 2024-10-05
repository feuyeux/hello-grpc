#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

# swiftformat --indent 4 --swiftversion 5.10 --exclude "**/*.grpc.swift,**/*.pb.swift" .
swift-format --indent 4 --swiftversion 6.0.1 --exclude "**/*.grpc.swift,**/*.pb.swift" .
