#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)"
cd "$SCRIPT_PATH" || exit
export JAVA_HOME=${JAVA_17_HOME}
rm -rf src/main/proto
mkdir src/main/proto
cd ..
ln -s "$PWD"/proto/landing.proto hello-grpc-java/src/main/proto/landing.proto
cd hello-grpc-java
ls -l src/main/proto
mvn clean install -DskipTests
