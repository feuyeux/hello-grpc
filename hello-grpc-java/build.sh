#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)"
cd "$SCRIPT_PATH" || exit

if [ "$(uname)" = "Darwin" ] ; then
   export JAVA_HOME=/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home
elif
    [ "$(expr substr $(uname -s) 1 5)" = "Linux" ] ; then
   echo "Linux"
elif
    [ "$(expr substr $(uname -s) 1 7)" = "MSYS_NT" ] ; then
    export JAVA_HOME=C:/jdk-20.0.2
else
    echo "Oops"
fi

mvn -v
mvn clean install -DskipTests "$@"