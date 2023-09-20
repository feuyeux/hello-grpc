#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
    cd "$(dirname "$0")" >/dev/null 2>&1 || exit
    pwd -P
)"
cd "$SCRIPT_PATH" || exit

if [ "$(uname)" = "Darwin" ]; then
    export JAVA_HOME=/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home
elif
    [ "$(expr substr $(uname -s) 1 5)" = "Linux" ]
then
    echo "Linux"
elif
    [ "$(expr substr $(uname -s) 1 7)" = "MSYS_NT" ]
then
    export JAVA_HOME=D:/zoo/jdk-21
elif
    [ "$(expr substr $(uname -s) 1 10)" = "MINGW64_NT" ]
then
    export JAVA_HOME=D:/zoo/jdk-21
else
    echo "Oops"
fi

mvn -v
mvn clean install -DskipTests "$@"
