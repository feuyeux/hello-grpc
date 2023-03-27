#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)"
cd "$SCRIPT_PATH" || exit
export JAVA_19_HOME=/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home
export JAVA_HOME=${JAVA_19_HOME}
mvn clean install -DskipTests "$@"
