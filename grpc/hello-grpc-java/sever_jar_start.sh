#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)"
cd "$SCRIPT_PATH" || exit
export JAVA_HOME=${JAVA_17_HOME}
mvn clean install -DskipTests -f server_pom.xml
export GRPC_HELLO_SECURE=Y
java -jar target/hello-grpc-java-server.jar
