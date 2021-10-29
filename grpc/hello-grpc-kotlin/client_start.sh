#!/usr/bin/env sh
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit
export JAVA_HOME=${JAVA_17_HOME}
cd client
gradle clean installShadowDist
build/install/client-shadow/bin/client