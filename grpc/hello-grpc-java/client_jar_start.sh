#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)"
export JAVA_HOME=${JAVA_17_HOME}
cd "$SCRIPT_PATH" || exit
mvn clean install -DskipTests -f client_pom.xml
export GRPC_HELLO_SECURE=Y
java -jar target/hello-grpc-java-client.jar
